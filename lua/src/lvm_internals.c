/* This is lvm.c, but only with macros and internal functions.
 * Does not include non-static functions.
 *
 * This helps reduce the size of the generated object files.
*/

#define LUA_CORE

#include "lprefix.h"

#include <float.h>
#include <limits.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "lua.h"

#include "ldebug.h"
#include "ldo.h"
#include "lfunc.h"
#include "lgc.h"
#include "lobject.h"
#include "lopcodes.h"
#include "lstate.h"
#include "lstring.h"
#include "ltable.h"
#include "ltm.h"
#include "lvm.h"


/*
** By default, use jump tables in the main interpreter loop on gcc
** and compatible compilers.
*/
#if !defined(LUA_USE_JUMPTABLE)
#if defined(__GNUC__)
#define LUA_USE_JUMPTABLE	1
#else
#define LUA_USE_JUMPTABLE	0
#endif
#endif



/* limit for table tag-method chains (to avoid infinite loops) */
#define MAXTAGLOOP	2000


/*
** 'l_intfitsf' checks whether a given integer is in the range that
** can be converted to a float without rounding. Used in comparisons.
*/

/* number of bits in the mantissa of a float */
#define NBM		(l_mathlim(MANT_DIG))

/*
** Check whether some integers may not fit in a float, testing whether
** (maxinteger >> NBM) > 0. (That implies (1 << NBM) <= maxinteger.)
** (The shifts are done in parts, to avoid shifting by more than the size
** of an integer. In a worst case, NBM == 113 for long double and
** sizeof(long) == 32.)
*/
#if ((((LUA_MAXINTEGER >> (NBM / 4)) >> (NBM / 4)) >> (NBM / 4)) \
	>> (NBM - (3 * (NBM / 4))))  >  0

/* limit for integers that fit in a float */
#define MAXINTFITSF	((lua_Unsigned)1 << NBM)

/* check whether 'i' is in the interval [-MAXINTFITSF, MAXINTFITSF] */
#define l_intfitsf(i)	((MAXINTFITSF + l_castS2U(i)) <= (2 * MAXINTFITSF))

#else  /* all integers fit in a float precisely */

#define l_intfitsf(i)	1

#endif

/*
** Try to convert a 'for' limit to an integer, preserving the semantics
** of the loop.  (The following explanation assumes a positive step;
** it is valid for negative steps mutatis mutandis.)
** Return true if the loop must not run.
** If the limit is an integer or can be converted to an integer,
** rounding down, that is the limit.
** Otherwise, check whether the limit can be converted to a float. If
** the float is too large, clip it to LUA_MAXINTEGER.  If the float
** is too negative, the loop should not run, because any initial
** integer value is greater than such limit; so, it returns true to
** signal that.
** (For this latter case, no integer limit would be correct; even a
** limit of LUA_MININTEGER would run the loop once for an initial
** value equal to LUA_MININTEGER.)
*/
static int forlimit (lua_State *L, lua_Integer init, const TValue *lim,
                                   lua_Integer *p, lua_Integer step) {
  if (!luaV_tointeger(lim, p, (step < 0 ? 2 : 1))) {
    /* not coercible to in integer */
    lua_Number flim;  /* try to convert to float */
    if (!tonumber(lim, &flim)) /* cannot convert to float? */
      luaG_forerror(L, lim, "limit");
    /* else 'flim' is a float out of integer bounds */
    if (luai_numlt(0, flim)) {  /* if it is positive, it is too large */
      if (step < 0) return 1;  /* initial value must be less than it */
      *p = LUA_MAXINTEGER;  /* truncate */
    }
    else {  /* it is less than min integer */
      if (step > 0) return 1;  /* initial value must be greater than it */
      *p = LUA_MININTEGER;  /* truncate */
    }
  }
  return (step > 0 ? init > *p : init < *p);  /* not to run? */
}

/*
** Compare two strings 'ls' x 'rs', returning an integer less-equal-
** -greater than zero if 'ls' is less-equal-greater than 'rs'.
** The code is a little tricky because it allows '\0' in the strings
** and it uses 'strcoll' (to respect locales) for each segments
** of the strings.
*/
static int l_strcmp (const TString *ls, const TString *rs) {
  const char *l = getstr(ls);
  size_t ll = tsslen(ls);
  const char *r = getstr(rs);
  size_t lr = tsslen(rs);
  for (;;) {  /* for each segment */
    int temp = strcoll(l, r);
    if (temp != 0)  /* not equal? */
      return temp;  /* done */
    else {  /* strings are equal up to a '\0' */
      size_t len = strlen(l);  /* index of first '\0' in both strings */
      if (len == lr)  /* 'rs' is finished? */
        return (len == ll) ? 0 : 1;  /* check 'ls' */
      else if (len == ll)  /* 'ls' is finished? */
        return -1;  /* 'ls' is less than 'rs' ('rs' is not finished) */
      /* both strings longer than 'len'; go on comparing after the '\0' */
      len++;
      l += len; ll -= len; r += len; lr -= len;
    }
  }
}


/*
** Check whether integer 'i' is less than float 'f'. If 'i' has an
** exact representation as a float ('l_intfitsf'), compare numbers as
** floats. Otherwise, use the equivalence 'i < f <=> i < ceil(f)'.
** If 'ceil(f)' is out of integer range, either 'f' is greater than
** all integers or less than all integers.
** (The test with 'l_intfitsf' is only for performance; the else
** case is correct for all values, but it is slow due to the conversion
** from float to int.)
** When 'f' is NaN, comparisons must result in false.
*/
static int LTintfloat (lua_Integer i, lua_Number f) {
  if (l_intfitsf(i))
    return luai_numlt(cast_num(i), f);  /* compare them as floats */
  else {  /* i < f <=> i < ceil(f) */
    lua_Integer fi;
    if (luaV_flttointeger(f, &fi, 2))  /* fi = ceil(f) */
      return i < fi;   /* compare them as integers */
    else  /* 'f' is either greater or less than all integers */
      return f > 0;  /* greater? */
  }
}


/*
** Check whether integer 'i' is less than or equal to float 'f'.
** See comments on previous function.
*/
static int LEintfloat (lua_Integer i, lua_Number f) {
  if (l_intfitsf(i))
    return luai_numle(cast_num(i), f);  /* compare them as floats */
  else {  /* i <= f <=> i <= floor(f) */
    lua_Integer fi;
    if (luaV_flttointeger(f, &fi, 1))  /* fi = floor(f) */
      return i <= fi;   /* compare them as integers */
    else  /* 'f' is either greater or less than all integers */
      return f > 0;  /* greater? */
  }
}


/*
** Check whether float 'f' is less than integer 'i'.
** See comments on previous function.
*/
static int LTfloatint (lua_Number f, lua_Integer i) {
  if (l_intfitsf(i))
    return luai_numlt(f, cast_num(i));  /* compare them as floats */
  else {  /* f < i <=> floor(f) < i */
    lua_Integer fi;
    if (luaV_flttointeger(f, &fi, 1))  /* fi = floor(f) */
      return fi < i;   /* compare them as integers */
    else  /* 'f' is either greater or less than all integers */
      return f < 0;  /* less? */
  }
}


/*
** Check whether float 'f' is less than or equal to integer 'i'.
** See comments on previous function.
*/
static int LEfloatint (lua_Number f, lua_Integer i) {
  if (l_intfitsf(i))
    return luai_numle(f, cast_num(i));  /* compare them as floats */
  else {  /* f <= i <=> ceil(f) <= i */
    lua_Integer fi;
    if (luaV_flttointeger(f, &fi, 2))  /* fi = ceil(f) */
      return fi <= i;   /* compare them as integers */
    else  /* 'f' is either greater or less than all integers */
      return f < 0;  /* less? */
  }
}


/*
** Return 'l < r', for numbers.
*/
static int LTnum (const TValue *l, const TValue *r) {
  lua_assert(ttisnumber(l) && ttisnumber(r));
  if (ttisinteger(l)) {
    lua_Integer li = ivalue(l);
    if (ttisinteger(r))
      return li < ivalue(r);  /* both are integers */
    else  /* 'l' is int and 'r' is float */
      return LTintfloat(li, fltvalue(r));  /* l < r ? */
  }
  else {
    lua_Number lf = fltvalue(l);  /* 'l' must be float */
    if (ttisfloat(r))
      return luai_numlt(lf, fltvalue(r));  /* both are float */
    else  /* 'l' is float and 'r' is int */
      return LTfloatint(lf, ivalue(r));
  }
}


/*
** Return 'l <= r', for numbers.
*/
static int LEnum (const TValue *l, const TValue *r) {
  lua_assert(ttisnumber(l) && ttisnumber(r));
  if (ttisinteger(l)) {
    lua_Integer li = ivalue(l);
    if (ttisinteger(r))
      return li <= ivalue(r);  /* both are integers */
    else  /* 'l' is int and 'r' is float */
      return LEintfloat(li, fltvalue(r));  /* l <= r ? */
  }
  else {
    lua_Number lf = fltvalue(l);  /* 'l' must be float */
    if (ttisfloat(r))
      return luai_numle(lf, fltvalue(r));  /* both are float */
    else  /* 'l' is float and 'r' is int */
      return LEfloatint(lf, ivalue(r));
  }
}


/*
** return 'l < r' for non-numbers.
*/
static int lessthanothers (lua_State *L, const TValue *l, const TValue *r) {
  lua_assert(!ttisnumber(l) || !ttisnumber(r));
  if (ttisstring(l) && ttisstring(r))  /* both are strings? */
    return l_strcmp(tsvalue(l), tsvalue(r)) < 0;
  else
    return luaT_callorderTM(L, l, r, TM_LT);
}

/*
** return 'l <= r' for non-numbers.
** If it needs a metamethod and there is no '__le', try '__lt', based
** on l <= r iff !(r < l) (assuming a total order). If the metamethod
** yields during this substitution, the continuation has to know about
** it (to negate the result of r<l); bit CIST_LEQ in the call status
** keeps that information.
*/
static int lessequalothers (lua_State *L, const TValue *l, const TValue *r) {
  lua_assert(!ttisnumber(l) || !ttisnumber(r));
  if (ttisstring(l) && ttisstring(r))  /* both are strings? */
    return l_strcmp(tsvalue(l), tsvalue(r)) <= 0;
  else
    return luaT_callorderTM(L, l, r, TM_LE);
}

/* macro used by 'luaV_concat' to ensure that element at 'o' is a string */
#define tostring(L,o)  \
	(ttisstring(o) || (cvt2str(o) && (luaO_tostring(L, o), 1)))

#define isemptystr(o)	(ttisshrstring(o) && tsvalue(o)->shrlen == 0)

/* number of bits in an integer */
#define NBITS	cast_int(sizeof(lua_Integer) * CHAR_BIT)

/*
** Shift left operation. (Shift right just negates 'y'.)
*/
#define luaV_shiftr(x,y)	luaV_shiftl(x,-(y))

/*
** create a new Lua closure, push it in the stack, and initialize
** its upvalues.
*/
static void pushclosure (lua_State *L, Proto *p, UpVal **encup, StkId base,
                         StkId ra) {
  int nup = p->sizeupvalues;
  Upvaldesc *uv = p->upvalues;
  int i;
  LClosure *ncl = luaF_newLclosure(L, nup);
  ncl->p = p;
  setclLvalue2s(L, ra, ncl);  /* anchor new closure in stack */
  for (i = 0; i < nup; i++) {  /* fill in its upvalues */
    if (uv[i].instack)  /* upvalue refers to local variable? */
      ncl->upvals[i] = luaF_findupval(L, base + uv[i].idx);
    else  /* get upvalue from enclosing function */
      ncl->upvals[i] = encup[uv[i].idx];
    luaC_objbarrier(L, ncl, ncl->upvals[i]);
  }
}

/*
** {==================================================================
** Macros for arithmetic/bitwise/comparison opcodes in 'luaV_execute'
** ===================================================================
*/

#define l_addi(L,a,b)	intop(+, a, b)
#define l_subi(L,a,b)	intop(-, a, b)
#define l_muli(L,a,b)	intop(*, a, b)
#define l_band(a,b)	intop(&, a, b)
#define l_bor(a,b)	intop(|, a, b)
#define l_bxor(a,b)	intop(^, a, b)

#define l_lti(a,b)	(a < b)
#define l_lei(a,b)	(a <= b)
#define l_gti(a,b)	(a > b)
#define l_gei(a,b)	(a >= b)


/*
** Auxiliary macro for arithmetic operations over floats and others
** with immediate operand. 'fop' is the float operation; 'tm' is the
** corresponding metamethod; 'flip' is true if operands were flipped.
*/
#define op_arithfI_aux(L,v1,imm,fop,tm,flip) {  \
  lua_Number nb;  \
  if (tonumberns(v1, nb)) {  \
    lua_Number fimm = cast_num(imm);  \
    pc++; setfltvalue(s2v(ra), fop(L, nb, fimm));  \
  }}


/*
** Arithmetic operations over floats and others with immediate operand.
*/
#define op_arithfI(L,fop,tm) {  \
  TValue *v1 = vRB(i);  \
  int imm = GETARG_sC(i);  \
  op_arithfI_aux(L, v1, imm, fop, tm, 0); }

/*
** Arithmetic operations with immediate operands. 'iop' is the integer
** operation.
*/
#define op_arithI(L,iop,fop,tm,flip) {  \
  TValue *v1 = vRB(i);  \
  int imm = GETARG_sC(i);  \
  if (ttisinteger(v1)) {  \
    lua_Integer iv1 = ivalue(v1);  \
    pc++; setivalue(s2v(ra), iop(L, iv1, imm));  \
  }  \
  else op_arithfI_aux(L, v1, imm, fop, tm, flip); }


/*
** Auxiliary function for arithmetic operations over floats and others
** with two register operands.
*/
#define op_arithf_aux(L,v1,v2,fop) {  \
  lua_Number n1; lua_Number n2;  \
  if (tonumberns(v1, n1) && tonumberns(v2, n2)) {  \
    pc++; setfltvalue(s2v(ra), fop(L, n1, n2));  \
  }}


/*
** Arithmetic operations over floats and others with register operands.
*/
#define op_arithf(L,fop) {  \
  TValue *v1 = vRB(i);  \
  TValue *v2 = vRC(i);  \
  op_arithf_aux(L, v1, v2, fop); }


/*
** Arithmetic operations with register operands.
*/
#define op_arith(L,iop,fop) {  \
  TValue *v1 = vRB(i);  \
  TValue *v2 = vRC(i);  \
  if (ttisinteger(v1) && ttisinteger(v2)) {  \
    lua_Integer i1 = ivalue(v1); lua_Integer i2 = ivalue(v2);  \
    pc++; setivalue(s2v(ra), iop(L, i1, i2));  \
  }  \
  else op_arithf_aux(L, v1, v2, fop); }


/*
** Arithmetic operations with K operands.
*/
#define op_arithK(L,iop,fop,flip) {  \
  TValue *v1 = vRB(i);  \
  TValue *v2 = KC(i);  \
  if (ttisinteger(v1) && ttisinteger(v2)) {  \
    lua_Integer i1 = ivalue(v1); lua_Integer i2 = ivalue(v2);  \
    pc++; setivalue(s2v(ra), iop(L, i1, i2));  \
  }  \
  else { \
    lua_Number n1; lua_Number n2;  \
    if (tonumberns(v1, n1) && tonumberns(v2, n2)) {  \
      pc++; setfltvalue(s2v(ra), fop(L, n1, n2));  \
    }}}


/*
** Arithmetic operations with K operands for floats.
*/
#define op_arithfK(L,fop) {  \
  TValue *v1 = vRB(i);  \
  TValue *v2 = KC(i);  \
  lua_Number n1; lua_Number n2;  \
  if (tonumberns(v1, n1) && tonumberns(v2, n2)) {  \
    pc++; setfltvalue(s2v(ra), fop(L, n1, n2));  \
  }}


/*
** Bitwise operations with constant operand.
*/
#define op_bitwiseK(L,op) {  \
  TValue *v1 = vRB(i);  \
  TValue *v2 = KC(i);  \
  lua_Integer i1;  \
  lua_Integer i2 = ivalue(v2);  \
  if (tointegerns(v1, &i1)) {  \
    pc++; setivalue(s2v(ra), op(i1, i2));  \
  }}


/*
** Bitwise operations with register operands.
*/
#define op_bitwise(L,op) {  \
  TValue *v1 = vRB(i);  \
  TValue *v2 = vRC(i);  \
  lua_Integer i1; lua_Integer i2;  \
  if (tointegerns(v1, &i1) && tointegerns(v2, &i2)) {  \
    pc++; setivalue(s2v(ra), op(i1, i2));  \
  }}


/*
** Order operations with register operands.
*/
#define op_order(L,opi,opf,other) {  \
        int cond;  \
        TValue *rb = vRB(i);  \
        if (ttisinteger(s2v(ra)) && ttisinteger(rb)) {  \
          lua_Integer ia = ivalue(s2v(ra));  \
          lua_Integer ib = ivalue(rb);  \
          cond = opi(ia, ib);  \
        }  \
        else if (ttisnumber(s2v(ra)) && ttisnumber(rb))  \
          cond = opf(s2v(ra), rb);  \
        else  \
          Protect(cond = other(L, s2v(ra), rb));  \
        docondjump(); }


/*
** Order operations with immediate operand.
*/
#define op_orderI(L,opi,opf,inv,tm) {  \
        int cond;  \
        int im = GETARG_sB(i);  \
        if (ttisinteger(s2v(ra)))  \
          cond = opi(ivalue(s2v(ra)), im);  \
        else if (ttisfloat(s2v(ra))) {  \
          lua_Number fa = fltvalue(s2v(ra));  \
          lua_Number fim = cast_num(im);  \
          cond = opf(fa, fim);  \
        }  \
        else {  \
          int isf = GETARG_C(i);  \
          Protect(cond = luaT_callorderiTM(L, s2v(ra), im, inv, isf, tm));  \
        }  \
        docondjump(); }

/* }================================================================== */


/*
** {==================================================================
** Function 'luaV_execute': main interpreter loop
** ===================================================================
*/

/*
** some macros for common tasks in 'luaV_execute'
*/


#define RA(i)	(base+GETARG_A(i))
#define RB(i)	(base+GETARG_B(i))
#define vRB(i)	s2v(RB(i))
#define KB(i)	(k+GETARG_B(i))
#define RC(i)	(base+GETARG_C(i))
#define vRC(i)	s2v(RC(i))
#define KC(i)	(k+GETARG_C(i))
#define RKC(i)	((TESTARG_k(i)) ? k + GETARG_C(i) : s2v(base + GETARG_C(i)))



#define updatetrap(ci)  (trap = ci->u.l.trap)

#define updatebase(ci)	(base = ci->func + 1)


#define updatestack(ci) { if (trap) { updatebase(ci); ra = RA(i); } }


/*
** Execute a jump instruction. The 'updatetrap' allows signals to stop
** tight loops. (Without it, the local copy of 'trap' could never change.)
*/
#define dojump(ci,i,e)	{ pc += GETARG_sJ(i) + e; updatetrap(ci); }


/* for test instructions, execute the jump instruction that follows it */
#define donextjump(ci)	{ Instruction ni = *pc; dojump(ci, ni, 1); }

/*
** do a conditional jump: skip next instruction if 'cond' is not what
** was expected (parameter 'k'), else do next instruction, which must
** be a jump.
*/
#define docondjump()	if (cond != GETARG_k(i)) pc++; else donextjump(ci);


/*
** Correct global 'pc'.
*/
#define savepc(L)	(ci->u.l.savedpc = pc)


/*
** Whenever code can raise errors, the global 'pc' and the global
** 'top' must be correct to report occasional errors.
*/
#define savestate(L,ci)		(savepc(L), L->top = ci->top)


/*
** Protect code that, in general, can raise errors, reallocate the
** stack, and change the hooks.
*/
#define Protect(exp)  (savestate(L,ci), (exp), updatetrap(ci))

/* special version that does not change the top */
#define ProtectNT(exp)  (savepc(L), (exp), updatetrap(ci))

/*
** Protect code that will finish the loop (returns) or can only raise
** errors. (That is, it will not return to the interpreter main loop
** after changing the stack or hooks.)
*/
#define halfProtect(exp)  (savestate(L,ci), (exp))

/* idem, but without changing the stack */
#define halfProtectNT(exp)  (savepc(L), (exp))


#define checkGC(L,c)  \
	{ luaC_condGC(L, L->top = (c),  /* limit of live values */ \
                         updatetrap(ci)); \
           luai_threadyield(L); }


/* fetch an instruction and prepare its execution */
#define vmfetch()	{ \
  if (trap) {  /* stack reallocation or hooks? */ \
    trap = luaG_traceexec(L, pc);  /* handle hooks */ \
    updatebase(ci);  /* correct stack */ \
  } \
  i = *(pc++); \
  ra = RA(i); /* WARNING: any stack reallocation invalidates 'ra' */ \
}

#define vmdispatch(o)	switch(o)
#define vmcase(l)	case l:
#define vmbreak		break

/* }================================================================== */
