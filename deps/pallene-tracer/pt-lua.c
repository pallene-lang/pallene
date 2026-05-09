/*
 * Copyright (c) 2024, The Pallene Developers
 * Pallene Tracer is licensed under the MIT license.
 * Please refer to the LICENSE and AUTHORS files for details
 * SPDX-License-Identifier: MIT
 */

/* THIS FILE IS A DEEP-COPY OF `lua.c` (lua interpreter frontend) WITH OUR CUSTOM DEBUG TRACEBACK
   FUNCTION BEING THE DEFAULT ONE. */

/* Lua Authors: Roberto Ierusalimschy, Waldemar Celes, Luiz Henrique de Figueiredo */

#define lua_c

/** lprefix.h **/
/*
** Allows POSIX/XSI stuff
*/
#if !defined(LUA_USE_C89)       /* { */

#if !defined(_XOPEN_SOURCE)
#define _XOPEN_SOURCE           600
#elif _XOPEN_SOURCE == 0
#undef _XOPEN_SOURCE  /* use -D_XOPEN_SOURCE=0 to undefine it */
#endif

/*
** Allows manipulation of large files in gcc and some other compilers
*/
#if !defined(LUA_32BITS) && !defined(_FILE_OFFSET_BITS)
#define _LARGEFILE_SOURCE       1
#define _FILE_OFFSET_BITS       64
#endif

#endif                          /* } */

/** lprefix.h end **/


/*
** Windows stuff
*/
#if defined(_WIN32)     /* { */

#if !defined(_CRT_SECURE_NO_WARNINGS)
#define _CRT_SECURE_NO_WARNINGS  /* avoid warnings about ISO C functions */
#endif

#endif                  /* } */


#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <signal.h>

#include "lua.h"

#include "lauxlib.h"
#include "lualib.h"

#define PT_IMPLEMENTATION
#include "ptracer.h"


/* Traceback ellipsis top threshold. How many frames should we print
   first to trigger ellipsis? */
#ifndef PT_LUA_TRACEBACK_TOP_THRESHOLD
#define PT_LUA_TRACEBACK_TOP_THRESHOLD           10
#endif // PT_LUA_TRACEBACK_TOP_THRESHOLD

/* This should always be 2 fewer than top threshold, for symmetry.
   Becuase we will always have 2 tail frames lingering around at
   at the end which is not captured by '_countlevels'. Lua also
   do it like this. */
#ifndef PT_LUA_TRACEBACK_BOTTOM_THRESHOLD
#define PT_LUA_TRACEBACK_BOTTOM_THRESHOLD        8
#endif // PT_RUN_TRACEBACK_BOTTOM_THRESHOLD


#if !defined(LUA_PROGNAME)
#define LUA_PROGNAME            "pt-lua"
#endif

#if !defined(LUA_INIT_VAR)
#define LUA_INIT_VAR            "LUA_INIT"
#endif

#define LUA_INITVARVERSION      LUA_INIT_VAR LUA_VERSUFFIX


static lua_State *globalL = NULL;

static const char *progname = LUA_PROGNAME;


#if defined(LUA_USE_POSIX)   /* { */

/*
** Use 'sigaction' when available.
*/
static void setsignal (int sig, void (*handler)(int)) {
  struct sigaction sa;
  sa.sa_handler = handler;
  sa.sa_flags = 0;
  sigemptyset(&sa.sa_mask);  /* do not mask any signal */
  sigaction(sig, &sa, NULL);
}

#else           /* }{ */

#define setsignal            signal

#endif                               /* } */


/* ---------------- PALLENE TRACER CODE ---------------- */

/* Global table name deduction. Can we find a function name? */
static bool findfield(lua_State *L, int fn_idx, int level) {
  if(level == 0 || !lua_istable(L, -1))
    return false;

  lua_pushnil(L);  /* Initial key. */

  while(lua_next(L, -2)) {
    /* We are only interested in String keys. */
    if(lua_type(L, -2) == LUA_TSTRING) {
      /* Avoid "_G" recursion in global table. The global table is also part of
         global table :). */
      if(!strcmp(lua_tostring(L, -2), "_G")) {
        /* Remove value and continue. */
        lua_pop(L, 1);
        continue;
      }

      /* Is it the function we are looking for? */
      if(lua_rawequal(L, fn_idx, -1)) {
        /* Remove value and keep name. */
        lua_pop(L, 1);
        return true;
      }
      /* If not go one level deeper and get the value recursively. */
      else if(findfield(L, fn_idx, level - 1)) {
        /* Remove the table but keep name. */
        lua_remove(L, -2);

        /* Add a "." in between. */
        lua_pushliteral(L, ".");
        lua_insert(L, -2);

        /* Concatenate last 3 values, resulting "table.some_func". */
        lua_concat(L, 3);

        return true;
      }
    }

    /* Pop the value. */
    lua_pop(L, 1);
  }

  return false;
}


/* Pushes a function name if found in the global table and returns true.
   Returns false otherwise. */
/* Expects the function to be pushed in the stack. */
static bool pushglobalfuncname(lua_State *L) {
  int top = lua_gettop(L);

  /* Start from the global table. */
  lua_pushglobaltable(L);

  if(findfield(L, top, 2)) {
    lua_remove(L, -2);
    return true;
  }

  lua_pop(L, 1);
  return false;
}


/* Returns the maximum number of levels in Lua stack. */
static int countlevels(lua_State *L) {
  lua_Debug ar;
  int li = 1, le = 1;

  /* Find an upper bound */
  while (lua_getstack(L, le, &ar)) {
    li = le, le *= 2;
  }

  /* Do a binary search */
  while (li < le) {
    int m = (li + le) / 2;

    if (lua_getstack(L, m, &ar)) li = m + 1;
    else le = m;
  }

  return le - 1;
}


/* Counts the number of white and black frames in the Pallene call stack. */
static void countframes(pt_fnstack_t *fnstack, int *mwhite, int *mblack) {
  *mwhite = *mblack = 0;

  for(int i = 0; i < fnstack->count; i++) {
    *mwhite += (fnstack->stack[i].type == PALLENE_TRACER_FRAME_TYPE_C);
    *mblack += (fnstack->stack[i].type == PALLENE_TRACER_FRAME_TYPE_LUA);
  }
}


/* This function is called by `debugtraceback` function decides whether to print the stack frame info string
   pushed onto the Lua stack. The function is also responsible for printing ellipsis (skipped frames). If we
   are skipping frames, the current frame pushed in stack is not printed. */
/* Pops the frame string from the Lua stack. */
/* pframes = Amount of printed frames; current count, nframes = Number of total frames to be printed. */
static void render(lua_State *L, luaL_Buffer *buf, int pframes, int nframes) {
  /* Should we print? Are we at any point in top or bottom printing threshold? */
  bool should_print = (pframes <= PT_LUA_TRACEBACK_TOP_THRESHOLD)
    || ((nframes - pframes) <= PT_LUA_TRACEBACK_BOTTOM_THRESHOLD);

  if(should_print)
    luaL_addvalue(buf);
  else {
    /* The frame string pushed onto the stack. We are not printing it, so just pop it out. */
    lua_pop(L, 1);

    /* Have we escaped the threshold to skip frames? */
    if(pframes == PT_LUA_TRACEBACK_TOP_THRESHOLD + 1) {
      lua_pushfstring(L, "\n\n    ... (Skipped %d frames) ...\n",
        nframes - (PT_LUA_TRACEBACK_TOP_THRESHOLD
        + PT_LUA_TRACEBACK_BOTTOM_THRESHOLD));
      luaL_addvalue(buf);
    }
  }
}


/* Pallene Tracer explicit traceback function to show Pallene call-stack
   tracebacks. */
int debugtraceback(lua_State *L, const char* msg) {
  lua_getfield(L, LUA_REGISTRYINDEX, PALLENE_TRACER_CONTAINER_ENTRY);
  pt_fnstack_t *fnstack = (pt_fnstack_t *) lua_touserdata(L, -1);
  pt_frame_t *stack = fnstack->stack;
  /* The point where we are in the Pallene stack. */
  int index = fnstack->count - 1;
  lua_pop(L, 1);

  /* Max number of white and black frames. */
  int mwhite, mblack;
  countframes(fnstack, &mwhite, &mblack);
  /* Max levels of Lua stack. */
  int mlevel = countlevels(L);

  /* Total frames we are going to print. */
  /* Black frames are used for switching and we will start from
     Lua stack level 1. */
  int nframes = mlevel + mwhite - mblack - 1;
  /* Amount of frames printed. */
  int pframes = 0;

  luaL_Buffer buf;
  luaL_buffinit(L, &buf);
  lua_pushfstring(L, "%s\nstack traceback:", msg);
  luaL_addvalue(&buf);

  lua_Debug ar;
  int level = 1;
  const char *tname;

  while(lua_getstack(L, level++, &ar)) {
    /* Get information regarding the frame: name, source, linenumbers etc. */
    lua_getinfo(L, "Slnf", &ar);

    /* If the frame is a C frame. */
    if(lua_iscfunction(L, -1)) {
      if(index >= 0) {
        /* Check whether this frame is tracked (C interface frames). */
        int check = index;
        while(stack[check].type != PALLENE_TRACER_FRAME_TYPE_LUA)
          check--;

        /* If the frame matches, we switch to printing Pallene frames. */
        if(lua_tocfunction(L, -1) == stack[check].shared.c_fnptr) {
          lua_pop(L, 1);  /* the function */

          /* Now print all the frames in Pallene stack. */
          for(; index > check; index--) {
            lua_pushfstring(L, "\n    %s:%d: in function '%s'",
              stack[index].shared.details->filename,
              stack[index].line, stack[index].shared.details->fn_name);
            pframes++;  /* We are printing the frame regardless of frame visibility. */
            render(L, &buf, pframes, nframes);
          }

          /* 'check' idx is guaranteed to be a Lua interface frame.
             Which is basically our 'stack' index at this point. So,
             we simply ignore the Lua interface frame. */
          index--;

          /* We are done. */
          continue;
        }
      }

      /* Then it's an untracked C frame. */
      if(pushglobalfuncname(L)) {
        tname = lua_tostring(L, -1);
        lua_pop(L, 1);
      } else tname = "<?>";

      lua_pop(L, 1);  /* the function */
      lua_pushfstring(L, "\n    C: in function '%s'", tname);
      pframes++;
      render(L, &buf, pframes, nframes);
    } else {
      /* It's a Lua frame. */

      /* Do we have a name? */
      if(*ar.namewhat != '\0') {
        lua_pushfstring(L, "function '%s'", ar.name);
        tname = lua_tostring(L, -1);
        lua_pop(L, 1);
      }
      /* Is it the main chunk? */
      else if(*ar.what == 'm')
        tname = "<main>";
      /* Can we deduce the name from the global table? */
      else if(pushglobalfuncname(L)) {
        lua_pushfstring(L, "function '%s'", lua_tostring(L, -1));
        tname = lua_tostring(L, -1);
        lua_pop(L, 2);
      } else tname = "function '<?>'";

      lua_pop(L, 1);  /* the function */
      lua_pushfstring(L, "\n    %s:%d: in %s", ar.short_src,
        ar.currentline, tname);
      pframes++;
      render(L, &buf, pframes, nframes);
    }
  }

  luaL_pushresult(&buf);
  return 1;
}

/* ---------------- PALLENE TRACER CODE END ---------------- */


/*
** Hook set by signal function to stop the interpreter.
*/
static void lstop (lua_State *L, lua_Debug *ar) {
  (void)ar;  /* unused arg. */
  lua_sethook(L, NULL, 0, 0);  /* reset hook */
  luaL_error(L, "interrupted!");
}


/*
** Function to be called at a C signal. Because a C signal cannot
** just change a Lua state (as there is no proper synchronization),
** this function only sets a hook that, when called, will stop the
** interpreter.
*/
static void laction (int i) {
  int flag = LUA_MASKCALL | LUA_MASKRET | LUA_MASKLINE | LUA_MASKCOUNT;
  setsignal(i, SIG_DFL); /* if another SIGINT happens, terminate process */
  lua_sethook(globalL, lstop, flag, 1);
}


static void print_usage (const char *badoption) {
  lua_writestringerror("%s: ", progname);
  if (badoption[1] == 'e' || badoption[1] == 'l')
    lua_writestringerror("'%s' needs argument\n", badoption);
  else
    lua_writestringerror("unrecognized option '%s'\n", badoption);
  lua_writestringerror(
  "usage: %s [options] [script [args]]\n"
  "Available options are:\n"
  "  -e stat   execute string 'stat'\n"
  "  -i        enter interactive mode after executing 'script'\n"
  "  -l mod    require library 'mod' into global 'mod'\n"
  "  -l g=mod  require library 'mod' into global 'g'\n"
  "  -v        show version information\n"
  "  -E        ignore environment variables\n"
  "  -W        turn warnings on\n"
  "  --        stop handling options\n"
  "  -         stop handling options and execute stdin\n"
  ,
  progname);
}


/*
** Prints an error message, adding the program name in front of it
** (if present)
*/
static void l_message (const char *pname, const char *msg) {
  if (pname) lua_writestringerror("%s: ", pname);
  lua_writestringerror("%s\n", msg);
}


/*
** Check whether 'status' is not OK and, if so, prints the error
** message on the top of the stack.
*/
static int report (lua_State *L, int status) {
  if (status != LUA_OK) {
    const char *msg = lua_tostring(L, -1);
    if (msg == NULL)
      msg = "(error message not a string)";
    l_message(progname, msg);
    lua_pop(L, 1);  /* remove message */
  }
  return status;
}


/*
** Message handler used to run all chunks
*/
static int msghandler (lua_State *L) {
  const char *msg = lua_tostring(L, 1);
  if (msg == NULL) {  /* is error object not a string? */
    if (luaL_callmeta(L, 1, "__tostring") &&  /* does it have a metamethod */
        lua_type(L, -1) == LUA_TSTRING)  /* that produces a string? */
      return 1;  /* that is the message */
    else
      msg = lua_pushfstring(L, "(error object is a %s value)",
                               luaL_typename(L, 1));
  }
  // luaL_traceback(L, L, msg, 1);  /* append a standard traceback */

  /* -------- PALLENE TRACER CODE -------- */
  debugtraceback(L, msg);  /* Our custom debug traceback function */
  /* -------- PALLENE TRACER CODE END -------- */

  return 1;  /* return the traceback */
}


/*
** Interface to 'lua_pcall', which sets appropriate message function
** and C-signal handler. Used to run all chunks.
*/
static int docall (lua_State *L, int narg, int nres) {
  int status;
  int base = lua_gettop(L) - narg;  /* function index */
  lua_pushcfunction(L, msghandler);  /* push message handler */
  lua_insert(L, base);  /* put it under function and args */
  globalL = L;  /* to be available to 'laction' */
  setsignal(SIGINT, laction);  /* set C-signal handler */
  status = lua_pcall(L, narg, nres, base);
  setsignal(SIGINT, SIG_DFL); /* reset C-signal handler */
  lua_remove(L, base);  /* remove message handler from the stack */
  return status;
}


static void print_version (void) {
  lua_writestring(LUA_COPYRIGHT, strlen(LUA_COPYRIGHT));
  lua_writeline();
}


/*
** Create the 'arg' table, which stores all arguments from the
** command line ('argv'). It should be aligned so that, at index 0,
** it has 'argv[script]', which is the script name. The arguments
** to the script (everything after 'script') go to positive indices;
** other arguments (before the script name) go to negative indices.
** If there is no script name, assume interpreter's name as base.
** (If there is no interpreter's name either, 'script' is -1, so
** table sizes are zero.)
*/
static void createargtable (lua_State *L, char **argv, int argc, int script) {
  int i, narg;
  narg = argc - (script + 1);  /* number of positive indices */
  lua_createtable(L, narg, script + 1);
  for (i = 0; i < argc; i++) {
    lua_pushstring(L, argv[i]);
    lua_rawseti(L, -2, i - script);
  }
  lua_setglobal(L, "arg");
}


static int dochunk (lua_State *L, int status) {
  if (status == LUA_OK) status = docall(L, 0, 0);
  return report(L, status);
}


static int dofile (lua_State *L, const char *name) {
  return dochunk(L, luaL_loadfile(L, name));
}


static int dostring (lua_State *L, const char *s, const char *name) {
  return dochunk(L, luaL_loadbuffer(L, s, strlen(s), name));
}


/*
** Receives 'globname[=modname]' and runs 'globname = require(modname)'.
** If there is no explicit modname and globname contains a '-', cut
** the suffix after '-' (the "version") to make the global name.
*/
static int dolibrary (lua_State *L, char *globname) {
  int status;
  char *suffix = NULL;
  char *modname = strchr(globname, '=');
  if (modname == NULL) {  /* no explicit name? */
    modname = globname;  /* module name is equal to global name */
    suffix = strchr(modname, *LUA_IGMARK);  /* look for a suffix mark */
  }
  else {
    *modname = '\0';  /* global name ends here */
    modname++;  /* module name starts after the '=' */
  }
  lua_getglobal(L, "require");
  lua_pushstring(L, modname);
  status = docall(L, 1, 1);  /* call 'require(modname)' */
  if (status == LUA_OK) {
    if (suffix != NULL)  /* is there a suffix mark? */
      *suffix = '\0';  /* remove suffix from global name */
    lua_setglobal(L, globname);  /* globname = require(modname) */
  }
  return report(L, status);
}


/*
** Push on the stack the contents of table 'arg' from 1 to #arg
*/
static int pushargs (lua_State *L) {
  int i, n;
  if (lua_getglobal(L, "arg") != LUA_TTABLE)
    luaL_error(L, "'arg' is not a table");
  n = (int)luaL_len(L, -1);
  luaL_checkstack(L, n + 3, "too many arguments to script");
  for (i = 1; i <= n; i++)
    lua_rawgeti(L, -i, i);
  lua_remove(L, -i);  /* remove table from the stack */
  return n;
}


static int handle_script (lua_State *L, char **argv) {
  int status;
  const char *fname = argv[0];
  if (strcmp(fname, "-") == 0 && strcmp(argv[-1], "--") != 0)
    fname = NULL;  /* stdin */
  status = luaL_loadfile(L, fname);
  if (status == LUA_OK) {
    int n = pushargs(L);  /* push arguments to script */
    status = docall(L, n, LUA_MULTRET);
  }
  return report(L, status);
}


/* bits of various argument indicators in 'args' */
#define has_error       1       /* bad option */
#define has_i           2       /* -i */
#define has_v           4       /* -v */
#define has_e           8       /* -e */
#define has_E           16      /* -E */


/*
** Traverses all arguments from 'argv', returning a mask with those
** needed before running any Lua code or an error code if it finds any
** invalid argument. In case of error, 'first' is the index of the bad
** argument.  Otherwise, 'first' is -1 if there is no program name,
** 0 if there is no script name, or the index of the script name.
*/
static int collectargs (char **argv, int *first) {
  int args = 0;
  int i;
  if (argv[0] != NULL) {  /* is there a program name? */
    if (argv[0][0])  /* not empty? */
      progname = argv[0];  /* save it */
  }
  else {  /* no program name */
    *first = -1;
    return 0;
  }
  for (i = 1; argv[i] != NULL; i++) {  /* handle arguments */
    *first = i;
    if (argv[i][0] != '-')  /* not an option? */
        return args;  /* stop handling options */
    switch (argv[i][1]) {  /* else check option */
      case '-':  /* '--' */
        if (argv[i][2] != '\0')  /* extra characters after '--'? */
          return has_error;  /* invalid option */
        *first = i + 1;
        return args;
      case '\0':  /* '-' */
        return args;  /* script "name" is '-' */
      case 'E':
        if (argv[i][2] != '\0')  /* extra characters? */
          return has_error;  /* invalid option */
        args |= has_E;
        break;
      case 'W':
        if (argv[i][2] != '\0')  /* extra characters? */
          return has_error;  /* invalid option */
        break;
      case 'i':
        args |= has_i;  /* (-i implies -v) *//* FALLTHROUGH */
      case 'v':
        if (argv[i][2] != '\0')  /* extra characters? */
          return has_error;  /* invalid option */
        args |= has_v;
        break;
      case 'e':
        args |= has_e;  /* FALLTHROUGH */
      case 'l':  /* both options need an argument */
        if (argv[i][2] == '\0') {  /* no concatenated argument? */
          i++;  /* try next 'argv' */
          if (argv[i] == NULL || argv[i][0] == '-')
            return has_error;  /* no next argument or it is another option */
        }
        break;
      default:  /* invalid option */
        return has_error;
    }
  }
  *first = 0;  /* no script name */
  return args;
}


/*
** Processes options 'e' and 'l', which involve running Lua code, and
** 'W', which also affects the state.
** Returns 0 if some code raises an error.
*/
static int runargs (lua_State *L, char **argv, int n) {
  int i;
  for (i = 1; i < n; i++) {
    int option = argv[i][1];
    lua_assert(argv[i][0] == '-');  /* already checked */
    switch (option) {
      case 'e':  case 'l': {
        int status;
        char *extra = argv[i] + 2;  /* both options need an argument */
        if (*extra == '\0') extra = argv[++i];
        lua_assert(extra != NULL);
        status = (option == 'e')
                 ? dostring(L, extra, "=(command line)")
                 : dolibrary(L, extra);
        if (status != LUA_OK) return 0;
        break;
      }
      case 'W':
        lua_warning(L, "@on", 0);  /* warnings on */
        break;
    }
  }
  return 1;
}


static int handle_luainit (lua_State *L) {
  const char *name = "=" LUA_INITVARVERSION;
  const char *init = getenv(name + 1);
  if (init == NULL) {
    name = "=" LUA_INIT_VAR;
    init = getenv(name + 1);  /* try alternative name */
  }
  if (init == NULL) return LUA_OK;
  else if (init[0] == '@')
    return dofile(L, init+1);
  else
    return dostring(L, init, name);
}


/*
** {==================================================================
** Read-Eval-Print Loop (REPL)
** ===================================================================
*/

#if !defined(LUA_PROMPT)
#define LUA_PROMPT              "> "
#define LUA_PROMPT2             ">> "
#endif

#if !defined(LUA_MAXINPUT)
#define LUA_MAXINPUT            512
#endif


/*
** lua_stdin_is_tty detects whether the standard input is a 'tty' (that
** is, whether we're running lua interactively).
*/
#if !defined(lua_stdin_is_tty)  /* { */

#if defined(LUA_USE_POSIX)      /* { */

#include <unistd.h>
#define lua_stdin_is_tty()      isatty(0)

#elif defined(LUA_USE_WINDOWS)  /* }{ */

#include <io.h>
#include <windows.h>

#define lua_stdin_is_tty()      _isatty(_fileno(stdin))

#else                           /* }{ */

/* ISO C definition */
#define lua_stdin_is_tty()      1  /* assume stdin is a tty */

#endif                          /* } */

#endif                          /* } */


/*
** lua_readline defines how to show a prompt and then read a line from
** the standard input.
** lua_saveline defines how to "save" a read line in a "history".
** lua_freeline defines how to free a line read by lua_readline.
*/
#if !defined(lua_readline)      /* { */

#if defined(LUA_USE_READLINE)   /* { */

#include <readline/readline.h>
#include <readline/history.h>
#define lua_initreadline(L)     ((void)L, rl_readline_name="lua")
#define lua_readline(L,b,p)     ((void)L, ((b)=readline(p)) != NULL)
#define lua_saveline(L,line)    ((void)L, add_history(line))
#define lua_freeline(L,b)       ((void)L, free(b))

#else                           /* }{ */

#define lua_initreadline(L)  ((void)L)
#define lua_readline(L,b,p) \
        ((void)L, fputs(p, stdout), fflush(stdout),  /* show prompt */ \
        fgets(b, LUA_MAXINPUT, stdin) != NULL)  /* get line */
#define lua_saveline(L,line)    { (void)L; (void)line; }
#define lua_freeline(L,b)       { (void)L; (void)b; }

#endif                          /* } */

#endif                          /* } */


/*
** Return the string to be used as a prompt by the interpreter. Leave
** the string (or nil, if using the default value) on the stack, to keep
** it anchored.
*/
static const char *get_prompt (lua_State *L, int firstline) {
  if (lua_getglobal(L, firstline ? "_PROMPT" : "_PROMPT2") == LUA_TNIL)
    return (firstline ? LUA_PROMPT : LUA_PROMPT2);  /* use the default */
  else {  /* apply 'tostring' over the value */
    const char *p = luaL_tolstring(L, -1, NULL);
    lua_remove(L, -2);  /* remove original value */
    return p;
  }
}

/* mark in error messages for incomplete statements */
#define EOFMARK         "<eof>"
#define marklen         (sizeof(EOFMARK)/sizeof(char) - 1)


/*
** Check whether 'status' signals a syntax error and the error
** message at the top of the stack ends with the above mark for
** incomplete statements.
*/
static int incomplete (lua_State *L, int status) {
  if (status == LUA_ERRSYNTAX) {
    size_t lmsg;
    const char *msg = lua_tolstring(L, -1, &lmsg);
    if (lmsg >= marklen && strcmp(msg + lmsg - marklen, EOFMARK) == 0) {
      lua_pop(L, 1);
      return 1;
    }
  }
  return 0;  /* else... */
}


/*
** Prompt the user, read a line, and push it into the Lua stack.
*/
static int pushline (lua_State *L, int firstline) {
  char buffer[LUA_MAXINPUT];
  char *b = buffer;
  size_t l;
  const char *prmt = get_prompt(L, firstline);
  int readstatus = lua_readline(L, b, prmt);
  if (readstatus == 0)
    return 0;  /* no input (prompt will be popped by caller) */
  lua_pop(L, 1);  /* remove prompt */
  l = strlen(b);
  if (l > 0 && b[l-1] == '\n')  /* line ends with newline? */
    b[--l] = '\0';  /* remove it */
  if (firstline && b[0] == '=')  /* for compatibility with 5.2, ... */
    lua_pushfstring(L, "return %s", b + 1);  /* change '=' to 'return' */
  else
    lua_pushlstring(L, b, l);
  lua_freeline(L, b);
  return 1;
}


/*
** Try to compile line on the stack as 'return <line>;'; on return, stack
** has either compiled chunk or original line (if compilation failed).
*/
static int addreturn (lua_State *L) {
  const char *line = lua_tostring(L, -1);  /* original line */
  const char *retline = lua_pushfstring(L, "return %s;", line);
  int status = luaL_loadbuffer(L, retline, strlen(retline), "=stdin");
  if (status == LUA_OK) {
    lua_remove(L, -2);  /* remove modified line */
    if (line[0] != '\0')  /* non empty? */
      lua_saveline(L, line);  /* keep history */
  }
  else
    lua_pop(L, 2);  /* pop result from 'luaL_loadbuffer' and modified line */
  return status;
}


/*
** Read multiple lines until a complete Lua statement
*/
static int multiline (lua_State *L) {
  for (;;) {  /* repeat until gets a complete statement */
    size_t len;
    const char *line = lua_tolstring(L, 1, &len);  /* get what it has */
    int status = luaL_loadbuffer(L, line, len, "=stdin");  /* try it */
    if (!incomplete(L, status) || !pushline(L, 0)) {
      lua_saveline(L, line);  /* keep history */
      return status;  /* cannot or should not try to add continuation line */
    }
    lua_pushliteral(L, "\n");  /* add newline... */
    lua_insert(L, -2);  /* ...between the two lines */
    lua_concat(L, 3);  /* join them */
  }
}


/*
** Read a line and try to load (compile) it first as an expression (by
** adding "return " in front of it) and second as a statement. Return
** the final status of load/call with the resulting function (if any)
** in the top of the stack.
*/
static int loadline (lua_State *L) {
  int status;
  lua_settop(L, 0);
  if (!pushline(L, 1))
    return -1;  /* no input */
  if ((status = addreturn(L)) != LUA_OK)  /* 'return ...' did not work? */
    status = multiline(L);  /* try as command, maybe with continuation lines */
  lua_remove(L, 1);  /* remove line from the stack */
  lua_assert(lua_gettop(L) == 1);
  return status;
}


/*
** Prints (calling the Lua 'print' function) any values on the stack
*/
static void l_print (lua_State *L) {
  int n = lua_gettop(L);
  if (n > 0) {  /* any result to be printed? */
    luaL_checkstack(L, LUA_MINSTACK, "too many results to print");
    lua_getglobal(L, "print");
    lua_insert(L, 1);
    if (lua_pcall(L, n, 0, 0) != LUA_OK)
      l_message(progname, lua_pushfstring(L, "error calling 'print' (%s)",
                                             lua_tostring(L, -1)));
  }
}


/*
** Do the REPL: repeatedly read (load) a line, evaluate (call) it, and
** print any results.
*/
static void doREPL (lua_State *L) {
  int status;
  const char *oldprogname = progname;
  progname = NULL;  /* no 'progname' on errors in interactive mode */
  lua_initreadline(L);
  while ((status = loadline(L)) != -1) {
    if (status == LUA_OK)
      status = docall(L, 0, LUA_MULTRET);
    if (status == LUA_OK) l_print(L);
    else report(L, status);
  }
  lua_settop(L, 0);  /* clear stack */
  lua_writeline();
  progname = oldprogname;
}

/* }================================================================== */


/*
** Main body of stand-alone interpreter (to be called in protected mode).
** Reads the options and handles them all.
*/
static int pmain (lua_State *L) {
  int argc = (int)lua_tointeger(L, 1);
  char **argv = (char **)lua_touserdata(L, 2);
  int script;
  int args = collectargs(argv, &script);
  int optlim = (script > 0) ? script : argc; /* first argv not an option */
  luaL_checkversion(L);  /* check that interpreter has correct version */
  if (args == has_error) {  /* bad arg? */
    print_usage(argv[script]);  /* 'script' has index of bad arg. */
    return 0;
  }
  if (args & has_v)  /* option '-v'? */
    print_version();
  if (args & has_E) {  /* option '-E'? */
    lua_pushboolean(L, 1);  /* signal for libraries to ignore env. vars. */
    lua_setfield(L, LUA_REGISTRYINDEX, "LUA_NOENV");
  }
  luaL_openlibs(L);  /* open standard libraries */
  createargtable(L, argv, argc, script);  /* create table 'arg' */
  lua_gc(L, LUA_GCRESTART);  /* start GC... */
  lua_gc(L, LUA_GCGEN, 0, 0);  /* ...in generational mode */
  if (!(args & has_E)) {  /* no option '-E'? */
    if (handle_luainit(L) != LUA_OK)  /* run LUA_INIT */
      return 0;  /* error running LUA_INIT */
  }
  if (!runargs(L, argv, optlim))  /* execute arguments -e and -l */
    return 0;  /* something failed */
  if (script > 0) {  /* execute main script (if there is one) */
    if (handle_script(L, argv + script) != LUA_OK)
      return 0;  /* interrupt in case of error */
  }
  if (args & has_i)  /* -i option? */
    doREPL(L);  /* do read-eval-print loop */
  else if (script < 1 && !(args & (has_e | has_v))) { /* no active option? */
    if (lua_stdin_is_tty()) {  /* running in interactive mode? */
      print_version();
      doREPL(L);  /* do read-eval-print loop */
    }
    else dofile(L, NULL);  /* executes stdin as a file */
  }
  lua_pushboolean(L, 1);  /* signal no errors */
  return 1;
}


int main (int argc, char **argv) {
  int status, result;
  lua_State *L = luaL_newstate();  /* create state */
  if (L == NULL) {
    l_message(argv[0], "cannot create state: not enough memory");
    return EXIT_FAILURE;
  }
  lua_gc(L, LUA_GCSTOP);  /* stop GC while building state */

  /* -------- PALLENE TRACER CODE -------- */
  (void) pallene_tracer_init(L);  /* initialize pallene tracer */
  lua_pop(L, 1);  /* We do not need the finalizer object here */
  /* -------- PALLENE TRACER CODE END -------- */

  lua_pushcfunction(L, &pmain);  /* to call 'pmain' in protected mode */
  lua_pushinteger(L, argc);  /* 1st argument */
  lua_pushlightuserdata(L, argv); /* 2nd argument */
  status = lua_pcall(L, 2, 1, 0);  /* do the call */
  result = lua_toboolean(L, -1);  /* get result */
  report(L, status);
  lua_close(L);
  return (result && status == LUA_OK) ? EXIT_SUCCESS : EXIT_FAILURE;
}
