#include "luaot_header.c"
 
// source = @benchmarks/nbody/lua.lua
// main function
static
void magic_implementation_00(lua_State *L, CallInfo *ci)
{
  LClosure *cl;
  TValue *k;
  StkId base;
  const Instruction *saved_pc;
  int trap;
  
 tailcall:
  trap = L->hookmask;
  cl = clLvalue(s2v(ci->func));
  k = cl->p->k;
  saved_pc = ci->u.l.savedpc;  /*no explicit program counter*/ 
  if (trap) {
    if (cl->p->is_vararg)
      trap = 0;  /* hooks will start after VARARGPREP instruction */
    else if (saved_pc == cl->p->code) /*first instruction (not resuming)?*/
      luaD_hookcall(L, ci);
    ci->u.l.trap = 1;  /* there may be other hooks */
  }
  base = ci->func + 1;
  /* main loop of interpreter */
  Instruction *function_code = cl->p->code;
  Instruction i;
  StkId ra;
  (void) function_code;
  (void) i;
  (void) ra;
 
  // 1	[1]	VARARGPREP	0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 1)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_02
  label_00 : {
    aot_vmfetch(0x0000004f);
    luaT_adjustvarargs(L, GETARG_A(i), ci, cl->p);
    updatetrap(ci);
    if (trap) {
      luaD_hookcall(L, ci);
      L->oldpc = LUA_AOT_PC + 1;  /* next opcode will be seen as a "new" line */
    }
  }
  
  // 2	[11]	CLOSURE  	0 0	; 0x1694ff0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x0000004d);
    Proto *p = cl->p->p[GETARG_Bx(i)];
    halfProtect(pushclosure(L, p, cl->upvals, base, ra));
    checkGC(L, ra + 1);
  }
  
  // 3	[31]	CLOSURE  	1 1	; 0x16958a0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x000080cd);
    Proto *p = cl->p->p[GETARG_Bx(i)];
    halfProtect(pushclosure(L, p, cl->upvals, base, ra));
    checkGC(L, ra + 1);
  }
  
  // 4	[63]	CLOSURE  	2 2	; 0x1695fb0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0x0001014d);
    Proto *p = cl->p->p[GETARG_Bx(i)];
    halfProtect(pushclosure(L, p, cl->upvals, base, ra));
    checkGC(L, ra + 1);
  }
  
  // 5	[69]	CLOSURE  	3 3	; 0x1696fd0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x000181cd);
    Proto *p = cl->p->p[GETARG_Bx(i)];
    halfProtect(pushclosure(L, p, cl->upvals, base, ra));
    checkGC(L, ra + 1);
  }
  
  // 6	[90]	CLOSURE  	4 4	; 0x1696840
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_07
  label_05 : {
    aot_vmfetch(0x0002024d);
    Proto *p = cl->p->p[GETARG_Bx(i)];
    halfProtect(pushclosure(L, p, cl->upvals, base, ra));
    checkGC(L, ra + 1);
  }
  
  // 7	[92]	NEWTABLE 	5 4 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_08
  label_06 : {
    aot_vmfetch(0x00040291);
    int b = GETARG_B(i);  /* log2(hash size) + 1 */
    int c = GETARG_C(i);  /* array size */
    Table *t;
    if (b > 0)
      b = 1 << (b - 1);  /* size is 2^(b - 1) */
    if (TESTARG_k(i))
      c += GETARG_Ax(0x00000050) * (MAXARG_C + 1);
    /* skip extra argument */
    L->top = ra + 1;  /* correct top in case of emergency GC */
    t = luaH_new(L);  /* memory allocation */
    sethvalue2s(L, ra, t);
    if (b != 0 || c != 0)
      luaH_resize(L, t, c, b);  /* idem */
    checkGC(L, ra + 1);
    goto LUA_AOT_SKIP1;
  }
  
  // 8	[92]	EXTRAARG 	0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_09
  label_07 : {
    aot_vmfetch(0x00000050);
    lua_assert(0);
  }
  
  // 9	[93]	SETFIELD 	5 0 0	; "new_body"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 9)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_10
  label_08 : {
    aot_vmfetch(0x00000290);
    const TValue *slot;
    TValue *rb = KB(i);
    TValue *rc = RKC(i);
    TString *key = tsvalue(rb);  /* key must be a string */
    if (luaV_fastget(L, s2v(ra), key, slot, luaH_getshortstr)) {
      luaV_finishfastset(L, s2v(ra), slot, rc);
    }
    else
      Protect(luaV_finishset(L, s2v(ra), rb, rc, slot));
  }
  
  // 10	[94]	SETFIELD 	5 1 1	; "offset_momentum"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 10)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_11
  label_09 : {
    aot_vmfetch(0x01010290);
    const TValue *slot;
    TValue *rb = KB(i);
    TValue *rc = RKC(i);
    TString *key = tsvalue(rb);  /* key must be a string */
    if (luaV_fastget(L, s2v(ra), key, slot, luaH_getshortstr)) {
      luaV_finishfastset(L, s2v(ra), slot, rc);
    }
    else
      Protect(luaV_finishset(L, s2v(ra), rb, rc, slot));
  }
  
  // 11	[95]	SETFIELD 	5 2 2	; "advance"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 11)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_12
  label_10 : {
    aot_vmfetch(0x02020290);
    const TValue *slot;
    TValue *rb = KB(i);
    TValue *rc = RKC(i);
    TString *key = tsvalue(rb);  /* key must be a string */
    if (luaV_fastget(L, s2v(ra), key, slot, luaH_getshortstr)) {
      luaV_finishfastset(L, s2v(ra), slot, rc);
    }
    else
      Protect(luaV_finishset(L, s2v(ra), rb, rc, slot));
  }
  
  // 12	[96]	SETFIELD 	5 3 3	; "advance_multiple_steps"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 12)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_13
  label_11 : {
    aot_vmfetch(0x03030290);
    const TValue *slot;
    TValue *rb = KB(i);
    TValue *rc = RKC(i);
    TString *key = tsvalue(rb);  /* key must be a string */
    if (luaV_fastget(L, s2v(ra), key, slot, luaH_getshortstr)) {
      luaV_finishfastset(L, s2v(ra), slot, rc);
    }
    else
      Protect(luaV_finishset(L, s2v(ra), rb, rc, slot));
  }
  
  // 13	[97]	SETFIELD 	5 4 4	; "energy"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 13)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_14
  label_12 : {
    aot_vmfetch(0x04040290);
    const TValue *slot;
    TValue *rb = KB(i);
    TValue *rc = RKC(i);
    TString *key = tsvalue(rb);  /* key must be a string */
    if (luaV_fastget(L, s2v(ra), key, slot, luaH_getshortstr)) {
      luaV_finishfastset(L, s2v(ra), slot, rc);
    }
    else
      Protect(luaV_finishset(L, s2v(ra), rb, rc, slot));
  }
  
  // 14	[98]	RETURN   	5 2 1	; 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 14)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_13 : {
    aot_vmfetch(0x010282c4);
    int n = GETARG_B(i) - 1;  /* number of results */
    int nparams1 = GETARG_C(i);
    if (n < 0)  /* not fixed? */
      n = cast_int(L->top - ra);  /* get what is available */
    savepc(ci);
    if (TESTARG_k(i)) {  /* may there be open upvalues? */
      if (L->top < ci->top)
        L->top = ci->top;
      luaF_close(L, base, LUA_OK);
      updatetrap(ci);
      updatestack(ci);
    }
    if (nparams1)  /* vararg function? */
      ci->func -= ci->u.l.nextraargs + nparams1;
    L->top = ra + n;  /* set call for 'luaD_poscall' */
    luaD_poscall(L, ci, n);
    return;
  }
  
  // 15	[98]	RETURN   	5 1 1	; 0 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 15)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_14 : {
    aot_vmfetch(0x010182c4);
    int n = GETARG_B(i) - 1;  /* number of results */
    int nparams1 = GETARG_C(i);
    if (n < 0)  /* not fixed? */
      n = cast_int(L->top - ra);  /* get what is available */
    savepc(ci);
    if (TESTARG_k(i)) {  /* may there be open upvalues? */
      if (L->top < ci->top)
        L->top = ci->top;
      luaF_close(L, base, LUA_OK);
      updatetrap(ci);
      updatestack(ci);
    }
    if (nparams1)  /* vararg function? */
      ci->func -= ci->u.l.nextraargs + nparams1;
    L->top = ra + n;  /* set call for 'luaD_poscall' */
    luaD_poscall(L, ci, n);
    return;
  }
  
}
 
// source = @benchmarks/nbody/lua.lua
// lines: 1 - 11
static
void magic_implementation_01(lua_State *L, CallInfo *ci)
{
  LClosure *cl;
  TValue *k;
  StkId base;
  const Instruction *saved_pc;
  int trap;
  
 tailcall:
  trap = L->hookmask;
  cl = clLvalue(s2v(ci->func));
  k = cl->p->k;
  saved_pc = ci->u.l.savedpc;  /*no explicit program counter*/ 
  if (trap) {
    if (cl->p->is_vararg)
      trap = 0;  /* hooks will start after VARARGPREP instruction */
    else if (saved_pc == cl->p->code) /*first instruction (not resuming)?*/
      luaD_hookcall(L, ci);
    ci->u.l.trap = 1;  /* there may be other hooks */
  }
  base = ci->func + 1;
  /* main loop of interpreter */
  Instruction *function_code = cl->p->code;
  Instruction i;
  StkId ra;
  (void) function_code;
  (void) i;
  (void) ra;
 
  // 1	[2]	NEWTABLE 	7 4 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 1)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_02
  label_00 : {
    aot_vmfetch(0x00040391);
    int b = GETARG_B(i);  /* log2(hash size) + 1 */
    int c = GETARG_C(i);  /* array size */
    Table *t;
    if (b > 0)
      b = 1 << (b - 1);  /* size is 2^(b - 1) */
    if (TESTARG_k(i))
      c += GETARG_Ax(0x00000050) * (MAXARG_C + 1);
    /* skip extra argument */
    L->top = ra + 1;  /* correct top in case of emergency GC */
    t = luaH_new(L);  /* memory allocation */
    sethvalue2s(L, ra, t);
    if (b != 0 || c != 0)
      luaH_resize(L, t, c, b);  /* idem */
    checkGC(L, ra + 1);
    goto LUA_AOT_SKIP1;
  }
  
  // 2	[2]	EXTRAARG 	0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x00000050);
    lua_assert(0);
  }
  
  // 3	[3]	SETFIELD 	7 0 0	; "x"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x00000390);
    const TValue *slot;
    TValue *rb = KB(i);
    TValue *rc = RKC(i);
    TString *key = tsvalue(rb);  /* key must be a string */
    if (luaV_fastget(L, s2v(ra), key, slot, luaH_getshortstr)) {
      luaV_finishfastset(L, s2v(ra), slot, rc);
    }
    else
      Protect(luaV_finishset(L, s2v(ra), rb, rc, slot));
  }
  
  // 4	[4]	SETFIELD 	7 1 1	; "y"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0x01010390);
    const TValue *slot;
    TValue *rb = KB(i);
    TValue *rc = RKC(i);
    TString *key = tsvalue(rb);  /* key must be a string */
    if (luaV_fastget(L, s2v(ra), key, slot, luaH_getshortstr)) {
      luaV_finishfastset(L, s2v(ra), slot, rc);
    }
    else
      Protect(luaV_finishset(L, s2v(ra), rb, rc, slot));
  }
  
  // 5	[5]	SETFIELD 	7 2 2	; "z"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x02020390);
    const TValue *slot;
    TValue *rb = KB(i);
    TValue *rc = RKC(i);
    TString *key = tsvalue(rb);  /* key must be a string */
    if (luaV_fastget(L, s2v(ra), key, slot, luaH_getshortstr)) {
      luaV_finishfastset(L, s2v(ra), slot, rc);
    }
    else
      Protect(luaV_finishset(L, s2v(ra), rb, rc, slot));
  }
  
  // 6	[6]	SETFIELD 	7 3 3	; "vx"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_07
  label_05 : {
    aot_vmfetch(0x03030390);
    const TValue *slot;
    TValue *rb = KB(i);
    TValue *rc = RKC(i);
    TString *key = tsvalue(rb);  /* key must be a string */
    if (luaV_fastget(L, s2v(ra), key, slot, luaH_getshortstr)) {
      luaV_finishfastset(L, s2v(ra), slot, rc);
    }
    else
      Protect(luaV_finishset(L, s2v(ra), rb, rc, slot));
  }
  
  // 7	[7]	SETFIELD 	7 4 4	; "vy"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_08
  label_06 : {
    aot_vmfetch(0x04040390);
    const TValue *slot;
    TValue *rb = KB(i);
    TValue *rc = RKC(i);
    TString *key = tsvalue(rb);  /* key must be a string */
    if (luaV_fastget(L, s2v(ra), key, slot, luaH_getshortstr)) {
      luaV_finishfastset(L, s2v(ra), slot, rc);
    }
    else
      Protect(luaV_finishset(L, s2v(ra), rb, rc, slot));
  }
  
  // 8	[8]	SETFIELD 	7 5 5	; "vz"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_09
  label_07 : {
    aot_vmfetch(0x05050390);
    const TValue *slot;
    TValue *rb = KB(i);
    TValue *rc = RKC(i);
    TString *key = tsvalue(rb);  /* key must be a string */
    if (luaV_fastget(L, s2v(ra), key, slot, luaH_getshortstr)) {
      luaV_finishfastset(L, s2v(ra), slot, rc);
    }
    else
      Protect(luaV_finishset(L, s2v(ra), rb, rc, slot));
  }
  
  // 9	[9]	SETFIELD 	7 6 6	; "mass"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 9)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_10
  label_08 : {
    aot_vmfetch(0x06060390);
    const TValue *slot;
    TValue *rb = KB(i);
    TValue *rc = RKC(i);
    TString *key = tsvalue(rb);  /* key must be a string */
    if (luaV_fastget(L, s2v(ra), key, slot, luaH_getshortstr)) {
      luaV_finishfastset(L, s2v(ra), slot, rc);
    }
    else
      Protect(luaV_finishset(L, s2v(ra), rb, rc, slot));
  }
  
  // 10	[10]	RETURN1  	7
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 10)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_09 : {
    aot_vmfetch(0x000203c6);
    if (L->hookmask) {
      L->top = ra + 1;
      halfProtectNT(luaD_poscall(L, ci, 1));  /* no hurry... */
    }
    else {  /* do the 'poscall' here */
      int nres = ci->nresults;
      L->ci = ci->previous;  /* back to caller */
      if (nres == 0)
        L->top = base - 1;  /* asked for no results */
      else {
        setobjs2s(L, base - 1, ra);  /* at least this result */
        L->top = base;
        while (--nres > 0)  /* complete missing results */
          setnilvalue(s2v(L->top++));
      }
    }
    return;
  }
  
  // 11	[11]	RETURN0  	
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 11)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_10 : {
    aot_vmfetch(0x000103c5);
    if (L->hookmask) {
      L->top = ra;
      halfProtectNT(luaD_poscall(L, ci, 0));  /* no hurry... */
    }
    else {  /* do the 'poscall' here */
      int nres = ci->nresults;
      L->ci = ci->previous;  /* back to caller */
      L->top = base - 1;
      while (nres-- > 0)
        setnilvalue(s2v(L->top++));  /* all results are nil */
    }
    return;
  }
  
}
 
// source = @benchmarks/nbody/lua.lua
// lines: 13 - 31
static
void magic_implementation_02(lua_State *L, CallInfo *ci)
{
  LClosure *cl;
  TValue *k;
  StkId base;
  const Instruction *saved_pc;
  int trap;
  
 tailcall:
  trap = L->hookmask;
  cl = clLvalue(s2v(ci->func));
  k = cl->p->k;
  saved_pc = ci->u.l.savedpc;  /*no explicit program counter*/ 
  if (trap) {
    if (cl->p->is_vararg)
      trap = 0;  /* hooks will start after VARARGPREP instruction */
    else if (saved_pc == cl->p->code) /*first instruction (not resuming)?*/
      luaD_hookcall(L, ci);
    ci->u.l.trap = 1;  /* there may be other hooks */
  }
  base = ci->func + 1;
  /* main loop of interpreter */
  Instruction *function_code = cl->p->code;
  Instruction i;
  StkId ra;
  (void) function_code;
  (void) i;
  (void) ra;
 
  // 1	[14]	LEN      	1 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 1)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_02
  label_00 : {
    aot_vmfetch(0x000000b2);
    Protect(luaV_objlen(L, ra, vRB(i)));
  }
  
  // 2	[15]	LOADF    	2 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x7fff8102);
    int b = GETARG_sBx(i);
    setfltvalue(s2v(ra), cast_num(b));
  }
  
  // 3	[16]	LOADF    	3 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x7fff8182);
    int b = GETARG_sBx(i);
    setfltvalue(s2v(ra), cast_num(b));
  }
  
  // 4	[17]	LOADF    	4 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0x7fff8202);
    int b = GETARG_sBx(i);
    setfltvalue(s2v(ra), cast_num(b));
  }
  
  // 5	[18]	LOADI    	5 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x80000281);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }
  
  // 6	[18]	MOVE     	6 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_07
  label_05 : {
    aot_vmfetch(0x00010300);
    setobjs2s(L, ra, RB(i));
  }
  
  // 7	[18]	LOADI    	7 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_08
  label_06 : {
    aot_vmfetch(0x80000381);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }
  
  // 8	[18]	FORPREP  	5 17	; to 26
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_09
  label_07 : {
    aot_vmfetch(0x000882c8);
    TValue *pinit = s2v(ra);
    TValue *plimit = s2v(ra + 1);
    TValue *pstep = s2v(ra + 2);
    savestate(L, ci);  /* in case of errors */
    if (ttisinteger(pinit) && ttisinteger(pstep)) { /* integer loop? */
      lua_Integer init = ivalue(pinit);
      lua_Integer step = ivalue(pstep);
      lua_Integer limit;
      if (step == 0)
        luaG_runerror(L, "'for' step is zero");
      setivalue(s2v(ra + 3), init);  /* control variable */
      if (forlimit(L, init, plimit, &limit, step))
        goto label_26; /* skip the loop */
      else {  /* prepare loop counter */
        lua_Unsigned count;
        if (step > 0) {  /* ascending loop? */
          count = l_castS2U(limit) - l_castS2U(init);
          if (step != 1)  /* avoid division in the too common case */
            count /= l_castS2U(step);
        }
        else {  /* step < 0; descending loop */
          count = l_castS2U(init) - l_castS2U(limit);
          /* 'step+1' avoids negating 'mininteger' */
          count /= l_castS2U(-(step + 1)) + 1u;
        }
        /* store the counter in place of the limit (which won't be
           needed anymore */
        setivalue(plimit, l_castU2S(count));
      }
    }
    else {  /* try making all values floats */
      lua_Number init; lua_Number limit; lua_Number step;
      if (unlikely(!tonumber(plimit, &limit)))
        luaG_forerror(L, plimit, "limit");
      if (unlikely(!tonumber(pstep, &step)))
        luaG_forerror(L, pstep, "step");
      if (unlikely(!tonumber(pinit, &init)))
        luaG_forerror(L, pinit, "initial value");
      if (step == 0)
        luaG_runerror(L, "'for' step is zero");
      if (luai_numlt(0, step) ? luai_numlt(limit, init)
                               : luai_numlt(init, limit))
        goto label_26; /* skip the loop */
      else {
        /* make sure internal values are all float */
        setfltvalue(plimit, limit);
        setfltvalue(pstep, step);
        setfltvalue(s2v(ra), init);  /* internal index */
        setfltvalue(s2v(ra + 3), init);  /* control variable */
      }
    }
  }
  
  // 9	[19]	GETTABLE 	9 0 8
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 9)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_10
  label_08 : {
    aot_vmfetch(0x0800048a);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = vRC(i);
    lua_Unsigned n;
    if (ttisinteger(rc)  /* fast track for integers? */
        ? (cast_void(n = ivalue(rc)), luaV_fastgeti(L, rb, n, slot))
        : luaV_fastget(L, rb, rc, slot, luaH_get)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 10	[20]	GETFIELD 	10 9 0	; "mass"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 10)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_11
  label_09 : {
    aot_vmfetch(0x0009050c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 11	[21]	GETFIELD 	11 9 1	; "vx"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 11)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_12
  label_10 : {
    aot_vmfetch(0x0109058c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 12	[21]	MUL      	11 11 10
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 12)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_13
  label_11 : {
    aot_vmfetch(0x0a0b05a2);
    op_arith(L, l_muli, luai_nummul);
  }
  
  // 13	[21]	MMBIN    	11 10 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 13)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_14
  label_12 : {
    aot_vmfetch(0x080a05ac);
    Instruction pi = 0x0a0b05a2; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 14	[21]	ADD      	2 2 11
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 14)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_15
  label_13 : {
    aot_vmfetch(0x0b020120);
    op_arith(L, l_addi, luai_numadd);
  }
  
  // 15	[21]	MMBIN    	2 11 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 15)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_16
  label_14 : {
    aot_vmfetch(0x060b012c);
    Instruction pi = 0x0b020120; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 16	[22]	GETFIELD 	11 9 2	; "vy"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 16)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_17
  label_15 : {
    aot_vmfetch(0x0209058c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 17	[22]	MUL      	11 11 10
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 17)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_18
  label_16 : {
    aot_vmfetch(0x0a0b05a2);
    op_arith(L, l_muli, luai_nummul);
  }
  
  // 18	[22]	MMBIN    	11 10 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 18)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_19
  label_17 : {
    aot_vmfetch(0x080a05ac);
    Instruction pi = 0x0a0b05a2; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 19	[22]	ADD      	3 3 11
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 19)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_20
  label_18 : {
    aot_vmfetch(0x0b0301a0);
    op_arith(L, l_addi, luai_numadd);
  }
  
  // 20	[22]	MMBIN    	3 11 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 20)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_21
  label_19 : {
    aot_vmfetch(0x060b01ac);
    Instruction pi = 0x0b0301a0; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 21	[23]	GETFIELD 	11 9 3	; "vz"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 21)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_22
  label_20 : {
    aot_vmfetch(0x0309058c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 22	[23]	MUL      	11 11 10
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 22)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_23
  label_21 : {
    aot_vmfetch(0x0a0b05a2);
    op_arith(L, l_muli, luai_nummul);
  }
  
  // 23	[23]	MMBIN    	11 10 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 23)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_24
  label_22 : {
    aot_vmfetch(0x080a05ac);
    Instruction pi = 0x0a0b05a2; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 24	[23]	ADD      	4 4 11
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 24)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_25
  label_23 : {
    aot_vmfetch(0x0b040220);
    op_arith(L, l_addi, luai_numadd);
  }
  
  // 25	[23]	MMBIN    	4 11 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 25)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_26
  label_24 : {
    aot_vmfetch(0x060b022c);
    Instruction pi = 0x0b040220; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 26	[18]	FORLOOP  	5 18	; to 9
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 26)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_27
  label_25 : {
    aot_vmfetch(0x000902c7);
    if (ttisinteger(s2v(ra + 2))) {  /* integer loop? */
      lua_Unsigned count = l_castS2U(ivalue(s2v(ra + 1)));
      if (count > 0) {  /* still more iterations? */
        lua_Integer step = ivalue(s2v(ra + 2));
        lua_Integer idx = ivalue(s2v(ra));  /* internal index */
        chgivalue(s2v(ra + 1), count - 1);  /* update counter */
        idx = intop(+, idx, step);  /* add step to index */
        chgivalue(s2v(ra), idx);  /* update internal index */
        setivalue(s2v(ra + 3), idx);  /* and control variable */
        goto label_08; /* jump back */
      }
    }
    else {  /* floating loop */
      lua_Number step = fltvalue(s2v(ra + 2));
      lua_Number limit = fltvalue(s2v(ra + 1));
      lua_Number idx = fltvalue(s2v(ra));
      idx = luai_numadd(L, idx, step);  /* increment index */
      if (luai_numlt(0, step) ? luai_numle(idx, limit)
                              : luai_numle(limit, idx)) {
        chgfltvalue(s2v(ra), idx);  /* update internal index */
        setfltvalue(s2v(ra + 3), idx);  /* and control variable */
        goto label_08; /* jump back */
      }
    }
    updatetrap(ci);  /* allows a signal to break the loop */
  }
  
  // 27	[26]	GETI     	5 0 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 27)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_28
  label_26 : {
    aot_vmfetch(0x0100028b);
    const TValue *slot;
    TValue *rb = vRB(i);
    int c = GETARG_C(i);
    if (luaV_fastgeti(L, rb, c, slot)) {
      setobj2s(L, ra, slot);
    }
    else {
      TValue key;
      setivalue(&key, c);
      Protect(luaV_finishget(L, rb, &key, ra, slot));
    }
  }
  
  // 28	[27]	GETFIELD 	6 5 0	; "mass"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 28)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_29
  label_27 : {
    aot_vmfetch(0x0005030c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 29	[28]	GETFIELD 	7 5 1	; "vx"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 29)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_30
  label_28 : {
    aot_vmfetch(0x0105038c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 30	[28]	DIV      	8 2 6
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 30)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_31
  label_29 : {
    aot_vmfetch(0x06020425);
    op_arithf(L, luai_numdiv);
  }
  
  // 31	[28]	MMBIN    	2 6 11	; __div
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 31)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_32
  label_30 : {
    aot_vmfetch(0x0b06012c);
    Instruction pi = 0x06020425; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 32	[28]	SUB      	7 7 8
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 32)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_33
  label_31 : {
    aot_vmfetch(0x080703a1);
    op_arith(L, l_subi, luai_numsub);
  }
  
  // 33	[28]	MMBIN    	7 8 7	; __sub
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 33)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_34
  label_32 : {
    aot_vmfetch(0x070803ac);
    Instruction pi = 0x080703a1; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 34	[28]	SETFIELD 	5 1 7	; "vx"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 34)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_35
  label_33 : {
    aot_vmfetch(0x07010290);
    const TValue *slot;
    TValue *rb = KB(i);
    TValue *rc = RKC(i);
    TString *key = tsvalue(rb);  /* key must be a string */
    if (luaV_fastget(L, s2v(ra), key, slot, luaH_getshortstr)) {
      luaV_finishfastset(L, s2v(ra), slot, rc);
    }
    else
      Protect(luaV_finishset(L, s2v(ra), rb, rc, slot));
  }
  
  // 35	[29]	GETFIELD 	7 5 2	; "vy"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 35)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_36
  label_34 : {
    aot_vmfetch(0x0205038c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 36	[29]	DIV      	8 3 6
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 36)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_37
  label_35 : {
    aot_vmfetch(0x06030425);
    op_arithf(L, luai_numdiv);
  }
  
  // 37	[29]	MMBIN    	3 6 11	; __div
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 37)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_38
  label_36 : {
    aot_vmfetch(0x0b0601ac);
    Instruction pi = 0x06030425; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 38	[29]	SUB      	7 7 8
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 38)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_39
  label_37 : {
    aot_vmfetch(0x080703a1);
    op_arith(L, l_subi, luai_numsub);
  }
  
  // 39	[29]	MMBIN    	7 8 7	; __sub
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 39)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_40
  label_38 : {
    aot_vmfetch(0x070803ac);
    Instruction pi = 0x080703a1; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 40	[29]	SETFIELD 	5 2 7	; "vy"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 40)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_41
  label_39 : {
    aot_vmfetch(0x07020290);
    const TValue *slot;
    TValue *rb = KB(i);
    TValue *rc = RKC(i);
    TString *key = tsvalue(rb);  /* key must be a string */
    if (luaV_fastget(L, s2v(ra), key, slot, luaH_getshortstr)) {
      luaV_finishfastset(L, s2v(ra), slot, rc);
    }
    else
      Protect(luaV_finishset(L, s2v(ra), rb, rc, slot));
  }
  
  // 41	[30]	GETFIELD 	7 5 3	; "vz"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 41)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_42
  label_40 : {
    aot_vmfetch(0x0305038c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 42	[30]	DIV      	8 4 6
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 42)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_43
  label_41 : {
    aot_vmfetch(0x06040425);
    op_arithf(L, luai_numdiv);
  }
  
  // 43	[30]	MMBIN    	4 6 11	; __div
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 43)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_44
  label_42 : {
    aot_vmfetch(0x0b06022c);
    Instruction pi = 0x06040425; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 44	[30]	SUB      	7 7 8
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 44)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_45
  label_43 : {
    aot_vmfetch(0x080703a1);
    op_arith(L, l_subi, luai_numsub);
  }
  
  // 45	[30]	MMBIN    	7 8 7	; __sub
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 45)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_46
  label_44 : {
    aot_vmfetch(0x070803ac);
    Instruction pi = 0x080703a1; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 46	[30]	SETFIELD 	5 3 7	; "vz"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 46)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_45 : {
    aot_vmfetch(0x07030290);
    const TValue *slot;
    TValue *rb = KB(i);
    TValue *rc = RKC(i);
    TString *key = tsvalue(rb);  /* key must be a string */
    if (luaV_fastget(L, s2v(ra), key, slot, luaH_getshortstr)) {
      luaV_finishfastset(L, s2v(ra), slot, rc);
    }
    else
      Protect(luaV_finishset(L, s2v(ra), rb, rc, slot));
  }
  
  // 47	[31]	RETURN0  	
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 47)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_46 : {
    aot_vmfetch(0x000103c5);
    if (L->hookmask) {
      L->top = ra;
      halfProtectNT(luaD_poscall(L, ci, 0));  /* no hurry... */
    }
    else {  /* do the 'poscall' here */
      int nres = ci->nresults;
      L->ci = ci->previous;  /* back to caller */
      L->top = base - 1;
      while (nres-- > 0)
        setnilvalue(s2v(L->top++));  /* all results are nil */
    }
    return;
  }
  
}
 
// source = @benchmarks/nbody/lua.lua
// lines: 33 - 63
static
void magic_implementation_03(lua_State *L, CallInfo *ci)
{
  LClosure *cl;
  TValue *k;
  StkId base;
  const Instruction *saved_pc;
  int trap;
  
 tailcall:
  trap = L->hookmask;
  cl = clLvalue(s2v(ci->func));
  k = cl->p->k;
  saved_pc = ci->u.l.savedpc;  /*no explicit program counter*/ 
  if (trap) {
    if (cl->p->is_vararg)
      trap = 0;  /* hooks will start after VARARGPREP instruction */
    else if (saved_pc == cl->p->code) /*first instruction (not resuming)?*/
      luaD_hookcall(L, ci);
    ci->u.l.trap = 1;  /* there may be other hooks */
  }
  base = ci->func + 1;
  /* main loop of interpreter */
  Instruction *function_code = cl->p->code;
  Instruction i;
  StkId ra;
  (void) function_code;
  (void) i;
  (void) ra;
 
  // 1	[34]	LEN      	2 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 1)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_02
  label_00 : {
    aot_vmfetch(0x00000132);
    Protect(luaV_objlen(L, ra, vRB(i)));
  }
  
  // 2	[35]	LOADI    	3 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x80000181);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }
  
  // 3	[35]	MOVE     	4 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x00020200);
    setobjs2s(L, ra, RB(i));
  }
  
  // 4	[35]	LOADI    	5 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0x80000281);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }
  
  // 5	[35]	FORPREP  	3 81	; to 87
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x002881c8);
    TValue *pinit = s2v(ra);
    TValue *plimit = s2v(ra + 1);
    TValue *pstep = s2v(ra + 2);
    savestate(L, ci);  /* in case of errors */
    if (ttisinteger(pinit) && ttisinteger(pstep)) { /* integer loop? */
      lua_Integer init = ivalue(pinit);
      lua_Integer step = ivalue(pstep);
      lua_Integer limit;
      if (step == 0)
        luaG_runerror(L, "'for' step is zero");
      setivalue(s2v(ra + 3), init);  /* control variable */
      if (forlimit(L, init, plimit, &limit, step))
        goto label_87; /* skip the loop */
      else {  /* prepare loop counter */
        lua_Unsigned count;
        if (step > 0) {  /* ascending loop? */
          count = l_castS2U(limit) - l_castS2U(init);
          if (step != 1)  /* avoid division in the too common case */
            count /= l_castS2U(step);
        }
        else {  /* step < 0; descending loop */
          count = l_castS2U(init) - l_castS2U(limit);
          /* 'step+1' avoids negating 'mininteger' */
          count /= l_castS2U(-(step + 1)) + 1u;
        }
        /* store the counter in place of the limit (which won't be
           needed anymore */
        setivalue(plimit, l_castU2S(count));
      }
    }
    else {  /* try making all values floats */
      lua_Number init; lua_Number limit; lua_Number step;
      if (unlikely(!tonumber(plimit, &limit)))
        luaG_forerror(L, plimit, "limit");
      if (unlikely(!tonumber(pstep, &step)))
        luaG_forerror(L, pstep, "step");
      if (unlikely(!tonumber(pinit, &init)))
        luaG_forerror(L, pinit, "initial value");
      if (step == 0)
        luaG_runerror(L, "'for' step is zero");
      if (luai_numlt(0, step) ? luai_numlt(limit, init)
                               : luai_numlt(init, limit))
        goto label_87; /* skip the loop */
      else {
        /* make sure internal values are all float */
        setfltvalue(plimit, limit);
        setfltvalue(pstep, step);
        setfltvalue(s2v(ra), init);  /* internal index */
        setfltvalue(s2v(ra + 3), init);  /* control variable */
      }
    }
  }
  
  // 6	[36]	GETTABLE 	7 0 6
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_07
  label_05 : {
    aot_vmfetch(0x0600038a);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = vRC(i);
    lua_Unsigned n;
    if (ttisinteger(rc)  /* fast track for integers? */
        ? (cast_void(n = ivalue(rc)), luaV_fastgeti(L, rb, n, slot))
        : luaV_fastget(L, rb, rc, slot, luaH_get)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 7	[37]	ADDI     	8 6 1 
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_08
  label_06 : {
    aot_vmfetch(0x80060413);
    op_arithI(L, l_addi, luai_numadd, TM_ADD, GETARG_k(i));
  }
  
  // 8	[37]	MMBINI   	6 1 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_09
  label_07 : {
    aot_vmfetch(0x0680032d);
    Instruction pi = 0x80060413;  /* original arith. expression */
    int imm = GETARG_sB(i);
    TMS tm = (TMS)GETARG_C(i);
    int flip = GETARG_k(i);
    StkId result = RA(pi);
    Protect(luaT_trybiniTM(L, s2v(ra), imm, flip, result, tm));
  }
  
  // 9	[37]	MOVE     	9 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 9)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_10
  label_08 : {
    aot_vmfetch(0x00020480);
    setobjs2s(L, ra, RB(i));
  }
  
  // 10	[37]	LOADI    	10 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 10)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_11
  label_09 : {
    aot_vmfetch(0x80000501);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }
  
  // 11	[37]	FORPREP  	8 74	; to 86
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 11)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_12
  label_10 : {
    aot_vmfetch(0x00250448);
    TValue *pinit = s2v(ra);
    TValue *plimit = s2v(ra + 1);
    TValue *pstep = s2v(ra + 2);
    savestate(L, ci);  /* in case of errors */
    if (ttisinteger(pinit) && ttisinteger(pstep)) { /* integer loop? */
      lua_Integer init = ivalue(pinit);
      lua_Integer step = ivalue(pstep);
      lua_Integer limit;
      if (step == 0)
        luaG_runerror(L, "'for' step is zero");
      setivalue(s2v(ra + 3), init);  /* control variable */
      if (forlimit(L, init, plimit, &limit, step))
        goto label_86; /* skip the loop */
      else {  /* prepare loop counter */
        lua_Unsigned count;
        if (step > 0) {  /* ascending loop? */
          count = l_castS2U(limit) - l_castS2U(init);
          if (step != 1)  /* avoid division in the too common case */
            count /= l_castS2U(step);
        }
        else {  /* step < 0; descending loop */
          count = l_castS2U(init) - l_castS2U(limit);
          /* 'step+1' avoids negating 'mininteger' */
          count /= l_castS2U(-(step + 1)) + 1u;
        }
        /* store the counter in place of the limit (which won't be
           needed anymore */
        setivalue(plimit, l_castU2S(count));
      }
    }
    else {  /* try making all values floats */
      lua_Number init; lua_Number limit; lua_Number step;
      if (unlikely(!tonumber(plimit, &limit)))
        luaG_forerror(L, plimit, "limit");
      if (unlikely(!tonumber(pstep, &step)))
        luaG_forerror(L, pstep, "step");
      if (unlikely(!tonumber(pinit, &init)))
        luaG_forerror(L, pinit, "initial value");
      if (step == 0)
        luaG_runerror(L, "'for' step is zero");
      if (luai_numlt(0, step) ? luai_numlt(limit, init)
                               : luai_numlt(init, limit))
        goto label_86; /* skip the loop */
      else {
        /* make sure internal values are all float */
        setfltvalue(plimit, limit);
        setfltvalue(pstep, step);
        setfltvalue(s2v(ra), init);  /* internal index */
        setfltvalue(s2v(ra + 3), init);  /* control variable */
      }
    }
  }
  
  // 12	[38]	GETTABLE 	12 0 11
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 12)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_13
  label_11 : {
    aot_vmfetch(0x0b00060a);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = vRC(i);
    lua_Unsigned n;
    if (ttisinteger(rc)  /* fast track for integers? */
        ? (cast_void(n = ivalue(rc)), luaV_fastgeti(L, rb, n, slot))
        : luaV_fastget(L, rb, rc, slot, luaH_get)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 13	[39]	GETFIELD 	13 7 0	; "x"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 13)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_14
  label_12 : {
    aot_vmfetch(0x0007068c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 14	[39]	GETFIELD 	14 12 0	; "x"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 14)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_15
  label_13 : {
    aot_vmfetch(0x000c070c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 15	[39]	SUB      	13 13 14
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 15)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_16
  label_14 : {
    aot_vmfetch(0x0e0d06a1);
    op_arith(L, l_subi, luai_numsub);
  }
  
  // 16	[39]	MMBIN    	13 14 7	; __sub
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 16)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_17
  label_15 : {
    aot_vmfetch(0x070e06ac);
    Instruction pi = 0x0e0d06a1; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 17	[40]	GETFIELD 	14 7 1	; "y"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 17)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_18
  label_16 : {
    aot_vmfetch(0x0107070c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 18	[40]	GETFIELD 	15 12 1	; "y"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 18)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_19
  label_17 : {
    aot_vmfetch(0x010c078c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 19	[40]	SUB      	14 14 15
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 19)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_20
  label_18 : {
    aot_vmfetch(0x0f0e0721);
    op_arith(L, l_subi, luai_numsub);
  }
  
  // 20	[40]	MMBIN    	14 15 7	; __sub
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 20)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_21
  label_19 : {
    aot_vmfetch(0x070f072c);
    Instruction pi = 0x0f0e0721; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 21	[41]	GETFIELD 	15 7 2	; "z"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 21)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_22
  label_20 : {
    aot_vmfetch(0x0207078c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 22	[41]	GETFIELD 	16 12 2	; "z"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 22)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_23
  label_21 : {
    aot_vmfetch(0x020c080c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 23	[41]	SUB      	15 15 16
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 23)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_24
  label_22 : {
    aot_vmfetch(0x100f07a1);
    op_arith(L, l_subi, luai_numsub);
  }
  
  // 24	[41]	MMBIN    	15 16 7	; __sub
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 24)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_25
  label_23 : {
    aot_vmfetch(0x071007ac);
    Instruction pi = 0x100f07a1; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 25	[43]	GETTABUP 	16 0 3	; _ENV "math"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 25)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_26
  label_24 : {
    aot_vmfetch(0x03000809);
    const TValue *slot;
    TValue *upval = cl->upvals[GETARG_B(i)]->v;
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, upval, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, upval, rc, ra, slot));
  }
  
  // 26	[43]	GETFIELD 	16 16 4	; "sqrt"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 26)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_27
  label_25 : {
    aot_vmfetch(0x0410080c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 27	[43]	MUL      	17 13 13
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 27)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_28
  label_26 : {
    aot_vmfetch(0x0d0d08a2);
    op_arith(L, l_muli, luai_nummul);
  }
  
  // 28	[43]	MMBIN    	13 13 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 28)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_29
  label_27 : {
    aot_vmfetch(0x080d06ac);
    Instruction pi = 0x0d0d08a2; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 29	[43]	MUL      	18 14 14
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 29)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_30
  label_28 : {
    aot_vmfetch(0x0e0e0922);
    op_arith(L, l_muli, luai_nummul);
  }
  
  // 30	[43]	MMBIN    	14 14 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 30)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_31
  label_29 : {
    aot_vmfetch(0x080e072c);
    Instruction pi = 0x0e0e0922; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 31	[43]	ADD      	17 17 18
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 31)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_32
  label_30 : {
    aot_vmfetch(0x121108a0);
    op_arith(L, l_addi, luai_numadd);
  }
  
  // 32	[43]	MMBIN    	17 18 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 32)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_33
  label_31 : {
    aot_vmfetch(0x061208ac);
    Instruction pi = 0x121108a0; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 33	[43]	MUL      	18 15 15
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 33)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_34
  label_32 : {
    aot_vmfetch(0x0f0f0922);
    op_arith(L, l_muli, luai_nummul);
  }
  
  // 34	[43]	MMBIN    	15 15 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 34)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_35
  label_33 : {
    aot_vmfetch(0x080f07ac);
    Instruction pi = 0x0f0f0922; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 35	[43]	ADD      	17 17 18
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 35)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_36
  label_34 : {
    aot_vmfetch(0x121108a0);
    op_arith(L, l_addi, luai_numadd);
  }
  
  // 36	[43]	MMBIN    	17 18 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 36)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_37
  label_35 : {
    aot_vmfetch(0x061208ac);
    Instruction pi = 0x121108a0; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 37	[43]	CALL     	16 2 2	; 1 in 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 37)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_38
  label_36 : {
    aot_vmfetch(0x02020842);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 38	[44]	MUL      	17 16 16
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 38)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_39
  label_37 : {
    aot_vmfetch(0x101008a2);
    op_arith(L, l_muli, luai_nummul);
  }
  
  // 39	[44]	MMBIN    	16 16 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 39)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_40
  label_38 : {
    aot_vmfetch(0x0810082c);
    Instruction pi = 0x101008a2; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 40	[44]	MUL      	17 17 16
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 40)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_41
  label_39 : {
    aot_vmfetch(0x101108a2);
    op_arith(L, l_muli, luai_nummul);
  }
  
  // 41	[44]	MMBIN    	17 16 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 41)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_42
  label_40 : {
    aot_vmfetch(0x081008ac);
    Instruction pi = 0x101108a2; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 42	[44]	DIV      	17 1 17
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 42)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_43
  label_41 : {
    aot_vmfetch(0x110108a5);
    op_arithf(L, luai_numdiv);
  }
  
  // 43	[44]	MMBIN    	1 17 11	; __div
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 43)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_44
  label_42 : {
    aot_vmfetch(0x0b1100ac);
    Instruction pi = 0x110108a5; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 44	[46]	GETFIELD 	18 12 5	; "mass"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 44)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_45
  label_43 : {
    aot_vmfetch(0x050c090c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 45	[46]	MUL      	18 18 17
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 45)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_46
  label_44 : {
    aot_vmfetch(0x11120922);
    op_arith(L, l_muli, luai_nummul);
  }
  
  // 46	[46]	MMBIN    	18 17 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 46)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_47
  label_45 : {
    aot_vmfetch(0x0811092c);
    Instruction pi = 0x11120922; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 47	[47]	GETFIELD 	19 7 6	; "vx"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 47)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_48
  label_46 : {
    aot_vmfetch(0x0607098c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 48	[47]	MUL      	20 13 18
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 48)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_49
  label_47 : {
    aot_vmfetch(0x120d0a22);
    op_arith(L, l_muli, luai_nummul);
  }
  
  // 49	[47]	MMBIN    	13 18 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 49)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_50
  label_48 : {
    aot_vmfetch(0x081206ac);
    Instruction pi = 0x120d0a22; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 50	[47]	SUB      	19 19 20
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 50)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_51
  label_49 : {
    aot_vmfetch(0x141309a1);
    op_arith(L, l_subi, luai_numsub);
  }
  
  // 51	[47]	MMBIN    	19 20 7	; __sub
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 51)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_52
  label_50 : {
    aot_vmfetch(0x071409ac);
    Instruction pi = 0x141309a1; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 52	[47]	SETFIELD 	7 6 19	; "vx"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 52)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_53
  label_51 : {
    aot_vmfetch(0x13060390);
    const TValue *slot;
    TValue *rb = KB(i);
    TValue *rc = RKC(i);
    TString *key = tsvalue(rb);  /* key must be a string */
    if (luaV_fastget(L, s2v(ra), key, slot, luaH_getshortstr)) {
      luaV_finishfastset(L, s2v(ra), slot, rc);
    }
    else
      Protect(luaV_finishset(L, s2v(ra), rb, rc, slot));
  }
  
  // 53	[48]	GETFIELD 	19 7 7	; "vy"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 53)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_54
  label_52 : {
    aot_vmfetch(0x0707098c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 54	[48]	MUL      	20 14 18
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 54)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_55
  label_53 : {
    aot_vmfetch(0x120e0a22);
    op_arith(L, l_muli, luai_nummul);
  }
  
  // 55	[48]	MMBIN    	14 18 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 55)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_56
  label_54 : {
    aot_vmfetch(0x0812072c);
    Instruction pi = 0x120e0a22; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 56	[48]	SUB      	19 19 20
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 56)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_57
  label_55 : {
    aot_vmfetch(0x141309a1);
    op_arith(L, l_subi, luai_numsub);
  }
  
  // 57	[48]	MMBIN    	19 20 7	; __sub
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 57)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_58
  label_56 : {
    aot_vmfetch(0x071409ac);
    Instruction pi = 0x141309a1; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 58	[48]	SETFIELD 	7 7 19	; "vy"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 58)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_59
  label_57 : {
    aot_vmfetch(0x13070390);
    const TValue *slot;
    TValue *rb = KB(i);
    TValue *rc = RKC(i);
    TString *key = tsvalue(rb);  /* key must be a string */
    if (luaV_fastget(L, s2v(ra), key, slot, luaH_getshortstr)) {
      luaV_finishfastset(L, s2v(ra), slot, rc);
    }
    else
      Protect(luaV_finishset(L, s2v(ra), rb, rc, slot));
  }
  
  // 59	[49]	GETFIELD 	19 7 8	; "vz"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 59)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_60
  label_58 : {
    aot_vmfetch(0x0807098c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 60	[49]	MUL      	20 15 18
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 60)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_61
  label_59 : {
    aot_vmfetch(0x120f0a22);
    op_arith(L, l_muli, luai_nummul);
  }
  
  // 61	[49]	MMBIN    	15 18 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 61)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_62
  label_60 : {
    aot_vmfetch(0x081207ac);
    Instruction pi = 0x120f0a22; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 62	[49]	SUB      	19 19 20
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 62)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_63
  label_61 : {
    aot_vmfetch(0x141309a1);
    op_arith(L, l_subi, luai_numsub);
  }
  
  // 63	[49]	MMBIN    	19 20 7	; __sub
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 63)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_64
  label_62 : {
    aot_vmfetch(0x071409ac);
    Instruction pi = 0x141309a1; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 64	[49]	SETFIELD 	7 8 19	; "vz"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 64)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_65
  label_63 : {
    aot_vmfetch(0x13080390);
    const TValue *slot;
    TValue *rb = KB(i);
    TValue *rc = RKC(i);
    TString *key = tsvalue(rb);  /* key must be a string */
    if (luaV_fastget(L, s2v(ra), key, slot, luaH_getshortstr)) {
      luaV_finishfastset(L, s2v(ra), slot, rc);
    }
    else
      Protect(luaV_finishset(L, s2v(ra), rb, rc, slot));
  }
  
  // 65	[51]	GETFIELD 	19 7 5	; "mass"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 65)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_66
  label_64 : {
    aot_vmfetch(0x0507098c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 66	[51]	MUL      	19 19 17
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 66)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_67
  label_65 : {
    aot_vmfetch(0x111309a2);
    op_arith(L, l_muli, luai_nummul);
  }
  
  // 67	[51]	MMBIN    	19 17 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 67)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_68
  label_66 : {
    aot_vmfetch(0x081109ac);
    Instruction pi = 0x111309a2; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 68	[52]	GETFIELD 	20 12 6	; "vx"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 68)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_69
  label_67 : {
    aot_vmfetch(0x060c0a0c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 69	[52]	MUL      	21 13 19
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 69)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_70
  label_68 : {
    aot_vmfetch(0x130d0aa2);
    op_arith(L, l_muli, luai_nummul);
  }
  
  // 70	[52]	MMBIN    	13 19 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 70)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_71
  label_69 : {
    aot_vmfetch(0x081306ac);
    Instruction pi = 0x130d0aa2; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 71	[52]	ADD      	20 20 21
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 71)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_72
  label_70 : {
    aot_vmfetch(0x15140a20);
    op_arith(L, l_addi, luai_numadd);
  }
  
  // 72	[52]	MMBIN    	20 21 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 72)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_73
  label_71 : {
    aot_vmfetch(0x06150a2c);
    Instruction pi = 0x15140a20; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 73	[52]	SETFIELD 	12 6 20	; "vx"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 73)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_74
  label_72 : {
    aot_vmfetch(0x14060610);
    const TValue *slot;
    TValue *rb = KB(i);
    TValue *rc = RKC(i);
    TString *key = tsvalue(rb);  /* key must be a string */
    if (luaV_fastget(L, s2v(ra), key, slot, luaH_getshortstr)) {
      luaV_finishfastset(L, s2v(ra), slot, rc);
    }
    else
      Protect(luaV_finishset(L, s2v(ra), rb, rc, slot));
  }
  
  // 74	[53]	GETFIELD 	20 12 7	; "vy"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 74)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_75
  label_73 : {
    aot_vmfetch(0x070c0a0c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 75	[53]	MUL      	21 14 19
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 75)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_76
  label_74 : {
    aot_vmfetch(0x130e0aa2);
    op_arith(L, l_muli, luai_nummul);
  }
  
  // 76	[53]	MMBIN    	14 19 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 76)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_77
  label_75 : {
    aot_vmfetch(0x0813072c);
    Instruction pi = 0x130e0aa2; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 77	[53]	ADD      	20 20 21
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 77)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_78
  label_76 : {
    aot_vmfetch(0x15140a20);
    op_arith(L, l_addi, luai_numadd);
  }
  
  // 78	[53]	MMBIN    	20 21 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 78)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_79
  label_77 : {
    aot_vmfetch(0x06150a2c);
    Instruction pi = 0x15140a20; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 79	[53]	SETFIELD 	12 7 20	; "vy"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 79)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_80
  label_78 : {
    aot_vmfetch(0x14070610);
    const TValue *slot;
    TValue *rb = KB(i);
    TValue *rc = RKC(i);
    TString *key = tsvalue(rb);  /* key must be a string */
    if (luaV_fastget(L, s2v(ra), key, slot, luaH_getshortstr)) {
      luaV_finishfastset(L, s2v(ra), slot, rc);
    }
    else
      Protect(luaV_finishset(L, s2v(ra), rb, rc, slot));
  }
  
  // 80	[54]	GETFIELD 	20 12 8	; "vz"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 80)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_81
  label_79 : {
    aot_vmfetch(0x080c0a0c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 81	[54]	MUL      	21 15 19
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 81)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_82
  label_80 : {
    aot_vmfetch(0x130f0aa2);
    op_arith(L, l_muli, luai_nummul);
  }
  
  // 82	[54]	MMBIN    	15 19 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 82)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_83
  label_81 : {
    aot_vmfetch(0x081307ac);
    Instruction pi = 0x130f0aa2; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 83	[54]	ADD      	20 20 21
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 83)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_84
  label_82 : {
    aot_vmfetch(0x15140a20);
    op_arith(L, l_addi, luai_numadd);
  }
  
  // 84	[54]	MMBIN    	20 21 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 84)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_85
  label_83 : {
    aot_vmfetch(0x06150a2c);
    Instruction pi = 0x15140a20; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 85	[54]	SETFIELD 	12 8 20	; "vz"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 85)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_86
  label_84 : {
    aot_vmfetch(0x14080610);
    const TValue *slot;
    TValue *rb = KB(i);
    TValue *rc = RKC(i);
    TString *key = tsvalue(rb);  /* key must be a string */
    if (luaV_fastget(L, s2v(ra), key, slot, luaH_getshortstr)) {
      luaV_finishfastset(L, s2v(ra), slot, rc);
    }
    else
      Protect(luaV_finishset(L, s2v(ra), rb, rc, slot));
  }
  
  // 86	[37]	FORLOOP  	8 75	; to 12
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 86)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_87
  label_85 : {
    aot_vmfetch(0x00258447);
    if (ttisinteger(s2v(ra + 2))) {  /* integer loop? */
      lua_Unsigned count = l_castS2U(ivalue(s2v(ra + 1)));
      if (count > 0) {  /* still more iterations? */
        lua_Integer step = ivalue(s2v(ra + 2));
        lua_Integer idx = ivalue(s2v(ra));  /* internal index */
        chgivalue(s2v(ra + 1), count - 1);  /* update counter */
        idx = intop(+, idx, step);  /* add step to index */
        chgivalue(s2v(ra), idx);  /* update internal index */
        setivalue(s2v(ra + 3), idx);  /* and control variable */
        goto label_11; /* jump back */
      }
    }
    else {  /* floating loop */
      lua_Number step = fltvalue(s2v(ra + 2));
      lua_Number limit = fltvalue(s2v(ra + 1));
      lua_Number idx = fltvalue(s2v(ra));
      idx = luai_numadd(L, idx, step);  /* increment index */
      if (luai_numlt(0, step) ? luai_numle(idx, limit)
                              : luai_numle(limit, idx)) {
        chgfltvalue(s2v(ra), idx);  /* update internal index */
        setfltvalue(s2v(ra + 3), idx);  /* and control variable */
        goto label_11; /* jump back */
      }
    }
    updatetrap(ci);  /* allows a signal to break the loop */
  }
  
  // 87	[35]	FORLOOP  	3 82	; to 6
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 87)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_88
  label_86 : {
    aot_vmfetch(0x002901c7);
    if (ttisinteger(s2v(ra + 2))) {  /* integer loop? */
      lua_Unsigned count = l_castS2U(ivalue(s2v(ra + 1)));
      if (count > 0) {  /* still more iterations? */
        lua_Integer step = ivalue(s2v(ra + 2));
        lua_Integer idx = ivalue(s2v(ra));  /* internal index */
        chgivalue(s2v(ra + 1), count - 1);  /* update counter */
        idx = intop(+, idx, step);  /* add step to index */
        chgivalue(s2v(ra), idx);  /* update internal index */
        setivalue(s2v(ra + 3), idx);  /* and control variable */
        goto label_05; /* jump back */
      }
    }
    else {  /* floating loop */
      lua_Number step = fltvalue(s2v(ra + 2));
      lua_Number limit = fltvalue(s2v(ra + 1));
      lua_Number idx = fltvalue(s2v(ra));
      idx = luai_numadd(L, idx, step);  /* increment index */
      if (luai_numlt(0, step) ? luai_numle(idx, limit)
                              : luai_numle(limit, idx)) {
        chgfltvalue(s2v(ra), idx);  /* update internal index */
        setfltvalue(s2v(ra + 3), idx);  /* and control variable */
        goto label_05; /* jump back */
      }
    }
    updatetrap(ci);  /* allows a signal to break the loop */
  }
  
  // 88	[57]	LOADI    	3 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 88)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_89
  label_87 : {
    aot_vmfetch(0x80000181);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }
  
  // 89	[57]	MOVE     	4 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 89)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_90
  label_88 : {
    aot_vmfetch(0x00020200);
    setobjs2s(L, ra, RB(i));
  }
  
  // 90	[57]	LOADI    	5 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 90)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_91
  label_89 : {
    aot_vmfetch(0x80000281);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }
  
  // 91	[57]	FORPREP  	3 22	; to 114
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 91)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_92
  label_90 : {
    aot_vmfetch(0x000b01c8);
    TValue *pinit = s2v(ra);
    TValue *plimit = s2v(ra + 1);
    TValue *pstep = s2v(ra + 2);
    savestate(L, ci);  /* in case of errors */
    if (ttisinteger(pinit) && ttisinteger(pstep)) { /* integer loop? */
      lua_Integer init = ivalue(pinit);
      lua_Integer step = ivalue(pstep);
      lua_Integer limit;
      if (step == 0)
        luaG_runerror(L, "'for' step is zero");
      setivalue(s2v(ra + 3), init);  /* control variable */
      if (forlimit(L, init, plimit, &limit, step))
        goto label_114; /* skip the loop */
      else {  /* prepare loop counter */
        lua_Unsigned count;
        if (step > 0) {  /* ascending loop? */
          count = l_castS2U(limit) - l_castS2U(init);
          if (step != 1)  /* avoid division in the too common case */
            count /= l_castS2U(step);
        }
        else {  /* step < 0; descending loop */
          count = l_castS2U(init) - l_castS2U(limit);
          /* 'step+1' avoids negating 'mininteger' */
          count /= l_castS2U(-(step + 1)) + 1u;
        }
        /* store the counter in place of the limit (which won't be
           needed anymore */
        setivalue(plimit, l_castU2S(count));
      }
    }
    else {  /* try making all values floats */
      lua_Number init; lua_Number limit; lua_Number step;
      if (unlikely(!tonumber(plimit, &limit)))
        luaG_forerror(L, plimit, "limit");
      if (unlikely(!tonumber(pstep, &step)))
        luaG_forerror(L, pstep, "step");
      if (unlikely(!tonumber(pinit, &init)))
        luaG_forerror(L, pinit, "initial value");
      if (step == 0)
        luaG_runerror(L, "'for' step is zero");
      if (luai_numlt(0, step) ? luai_numlt(limit, init)
                               : luai_numlt(init, limit))
        goto label_114; /* skip the loop */
      else {
        /* make sure internal values are all float */
        setfltvalue(plimit, limit);
        setfltvalue(pstep, step);
        setfltvalue(s2v(ra), init);  /* internal index */
        setfltvalue(s2v(ra + 3), init);  /* control variable */
      }
    }
  }
  
  // 92	[58]	GETTABLE 	7 0 6
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 92)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_93
  label_91 : {
    aot_vmfetch(0x0600038a);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = vRC(i);
    lua_Unsigned n;
    if (ttisinteger(rc)  /* fast track for integers? */
        ? (cast_void(n = ivalue(rc)), luaV_fastgeti(L, rb, n, slot))
        : luaV_fastget(L, rb, rc, slot, luaH_get)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 93	[59]	GETFIELD 	8 7 0	; "x"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 93)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_94
  label_92 : {
    aot_vmfetch(0x0007040c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 94	[59]	GETFIELD 	9 7 6	; "vx"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 94)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_95
  label_93 : {
    aot_vmfetch(0x0607048c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 95	[59]	MUL      	9 1 9
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 95)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_96
  label_94 : {
    aot_vmfetch(0x090104a2);
    op_arith(L, l_muli, luai_nummul);
  }
  
  // 96	[59]	MMBIN    	1 9 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 96)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_97
  label_95 : {
    aot_vmfetch(0x080900ac);
    Instruction pi = 0x090104a2; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 97	[59]	ADD      	8 8 9
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 97)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_98
  label_96 : {
    aot_vmfetch(0x09080420);
    op_arith(L, l_addi, luai_numadd);
  }
  
  // 98	[59]	MMBIN    	8 9 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 98)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_99
  label_97 : {
    aot_vmfetch(0x0609042c);
    Instruction pi = 0x09080420; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 99	[59]	SETFIELD 	7 0 8	; "x"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 99)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_100
  label_98 : {
    aot_vmfetch(0x08000390);
    const TValue *slot;
    TValue *rb = KB(i);
    TValue *rc = RKC(i);
    TString *key = tsvalue(rb);  /* key must be a string */
    if (luaV_fastget(L, s2v(ra), key, slot, luaH_getshortstr)) {
      luaV_finishfastset(L, s2v(ra), slot, rc);
    }
    else
      Protect(luaV_finishset(L, s2v(ra), rb, rc, slot));
  }
  
  // 100	[60]	GETFIELD 	8 7 1	; "y"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 100)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_101
  label_99 : {
    aot_vmfetch(0x0107040c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 101	[60]	GETFIELD 	9 7 7	; "vy"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 101)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_102
  label_100 : {
    aot_vmfetch(0x0707048c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 102	[60]	MUL      	9 1 9
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 102)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_103
  label_101 : {
    aot_vmfetch(0x090104a2);
    op_arith(L, l_muli, luai_nummul);
  }
  
  // 103	[60]	MMBIN    	1 9 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 103)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_104
  label_102 : {
    aot_vmfetch(0x080900ac);
    Instruction pi = 0x090104a2; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 104	[60]	ADD      	8 8 9
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 104)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_105
  label_103 : {
    aot_vmfetch(0x09080420);
    op_arith(L, l_addi, luai_numadd);
  }
  
  // 105	[60]	MMBIN    	8 9 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 105)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_106
  label_104 : {
    aot_vmfetch(0x0609042c);
    Instruction pi = 0x09080420; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 106	[60]	SETFIELD 	7 1 8	; "y"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 106)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_107
  label_105 : {
    aot_vmfetch(0x08010390);
    const TValue *slot;
    TValue *rb = KB(i);
    TValue *rc = RKC(i);
    TString *key = tsvalue(rb);  /* key must be a string */
    if (luaV_fastget(L, s2v(ra), key, slot, luaH_getshortstr)) {
      luaV_finishfastset(L, s2v(ra), slot, rc);
    }
    else
      Protect(luaV_finishset(L, s2v(ra), rb, rc, slot));
  }
  
  // 107	[61]	GETFIELD 	8 7 2	; "z"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 107)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_108
  label_106 : {
    aot_vmfetch(0x0207040c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 108	[61]	GETFIELD 	9 7 8	; "vz"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 108)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_109
  label_107 : {
    aot_vmfetch(0x0807048c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 109	[61]	MUL      	9 1 9
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 109)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_110
  label_108 : {
    aot_vmfetch(0x090104a2);
    op_arith(L, l_muli, luai_nummul);
  }
  
  // 110	[61]	MMBIN    	1 9 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 110)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_111
  label_109 : {
    aot_vmfetch(0x080900ac);
    Instruction pi = 0x090104a2; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 111	[61]	ADD      	8 8 9
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 111)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_112
  label_110 : {
    aot_vmfetch(0x09080420);
    op_arith(L, l_addi, luai_numadd);
  }
  
  // 112	[61]	MMBIN    	8 9 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 112)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_113
  label_111 : {
    aot_vmfetch(0x0609042c);
    Instruction pi = 0x09080420; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 113	[61]	SETFIELD 	7 2 8	; "z"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 113)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_114
  label_112 : {
    aot_vmfetch(0x08020390);
    const TValue *slot;
    TValue *rb = KB(i);
    TValue *rc = RKC(i);
    TString *key = tsvalue(rb);  /* key must be a string */
    if (luaV_fastget(L, s2v(ra), key, slot, luaH_getshortstr)) {
      luaV_finishfastset(L, s2v(ra), slot, rc);
    }
    else
      Protect(luaV_finishset(L, s2v(ra), rb, rc, slot));
  }
  
  // 114	[57]	FORLOOP  	3 23	; to 92
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 114)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_113 : {
    aot_vmfetch(0x000b81c7);
    if (ttisinteger(s2v(ra + 2))) {  /* integer loop? */
      lua_Unsigned count = l_castS2U(ivalue(s2v(ra + 1)));
      if (count > 0) {  /* still more iterations? */
        lua_Integer step = ivalue(s2v(ra + 2));
        lua_Integer idx = ivalue(s2v(ra));  /* internal index */
        chgivalue(s2v(ra + 1), count - 1);  /* update counter */
        idx = intop(+, idx, step);  /* add step to index */
        chgivalue(s2v(ra), idx);  /* update internal index */
        setivalue(s2v(ra + 3), idx);  /* and control variable */
        goto label_91; /* jump back */
      }
    }
    else {  /* floating loop */
      lua_Number step = fltvalue(s2v(ra + 2));
      lua_Number limit = fltvalue(s2v(ra + 1));
      lua_Number idx = fltvalue(s2v(ra));
      idx = luai_numadd(L, idx, step);  /* increment index */
      if (luai_numlt(0, step) ? luai_numle(idx, limit)
                              : luai_numle(limit, idx)) {
        chgfltvalue(s2v(ra), idx);  /* update internal index */
        setfltvalue(s2v(ra + 3), idx);  /* and control variable */
        goto label_91; /* jump back */
      }
    }
    updatetrap(ci);  /* allows a signal to break the loop */
  }
  
  // 115	[63]	RETURN0  	
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 115)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_114 : {
    aot_vmfetch(0x000101c5);
    if (L->hookmask) {
      L->top = ra;
      halfProtectNT(luaD_poscall(L, ci, 0));  /* no hurry... */
    }
    else {  /* do the 'poscall' here */
      int nres = ci->nresults;
      L->ci = ci->previous;  /* back to caller */
      L->top = base - 1;
      while (nres-- > 0)
        setnilvalue(s2v(L->top++));  /* all results are nil */
    }
    return;
  }
  
}
 
// source = @benchmarks/nbody/lua.lua
// lines: 65 - 69
static
void magic_implementation_04(lua_State *L, CallInfo *ci)
{
  LClosure *cl;
  TValue *k;
  StkId base;
  const Instruction *saved_pc;
  int trap;
  
 tailcall:
  trap = L->hookmask;
  cl = clLvalue(s2v(ci->func));
  k = cl->p->k;
  saved_pc = ci->u.l.savedpc;  /*no explicit program counter*/ 
  if (trap) {
    if (cl->p->is_vararg)
      trap = 0;  /* hooks will start after VARARGPREP instruction */
    else if (saved_pc == cl->p->code) /*first instruction (not resuming)?*/
      luaD_hookcall(L, ci);
    ci->u.l.trap = 1;  /* there may be other hooks */
  }
  base = ci->func + 1;
  /* main loop of interpreter */
  Instruction *function_code = cl->p->code;
  Instruction i;
  StkId ra;
  (void) function_code;
  (void) i;
  (void) ra;
 
  // 1	[66]	LOADI    	3 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 1)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_02
  label_00 : {
    aot_vmfetch(0x80000181);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }
  
  // 2	[66]	MOVE     	4 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x00000200);
    setobjs2s(L, ra, RB(i));
  }
  
  // 3	[66]	LOADI    	5 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x80000281);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }
  
  // 4	[66]	FORPREP  	3 4	; to 9
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0x000201c8);
    TValue *pinit = s2v(ra);
    TValue *plimit = s2v(ra + 1);
    TValue *pstep = s2v(ra + 2);
    savestate(L, ci);  /* in case of errors */
    if (ttisinteger(pinit) && ttisinteger(pstep)) { /* integer loop? */
      lua_Integer init = ivalue(pinit);
      lua_Integer step = ivalue(pstep);
      lua_Integer limit;
      if (step == 0)
        luaG_runerror(L, "'for' step is zero");
      setivalue(s2v(ra + 3), init);  /* control variable */
      if (forlimit(L, init, plimit, &limit, step))
        goto label_09; /* skip the loop */
      else {  /* prepare loop counter */
        lua_Unsigned count;
        if (step > 0) {  /* ascending loop? */
          count = l_castS2U(limit) - l_castS2U(init);
          if (step != 1)  /* avoid division in the too common case */
            count /= l_castS2U(step);
        }
        else {  /* step < 0; descending loop */
          count = l_castS2U(init) - l_castS2U(limit);
          /* 'step+1' avoids negating 'mininteger' */
          count /= l_castS2U(-(step + 1)) + 1u;
        }
        /* store the counter in place of the limit (which won't be
           needed anymore */
        setivalue(plimit, l_castU2S(count));
      }
    }
    else {  /* try making all values floats */
      lua_Number init; lua_Number limit; lua_Number step;
      if (unlikely(!tonumber(plimit, &limit)))
        luaG_forerror(L, plimit, "limit");
      if (unlikely(!tonumber(pstep, &step)))
        luaG_forerror(L, pstep, "step");
      if (unlikely(!tonumber(pinit, &init)))
        luaG_forerror(L, pinit, "initial value");
      if (step == 0)
        luaG_runerror(L, "'for' step is zero");
      if (luai_numlt(0, step) ? luai_numlt(limit, init)
                               : luai_numlt(init, limit))
        goto label_09; /* skip the loop */
      else {
        /* make sure internal values are all float */
        setfltvalue(plimit, limit);
        setfltvalue(pstep, step);
        setfltvalue(s2v(ra), init);  /* internal index */
        setfltvalue(s2v(ra + 3), init);  /* control variable */
      }
    }
  }
  
  // 5	[67]	GETUPVAL 	7 0	; advance
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x00000387);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }
  
  // 6	[67]	MOVE     	8 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_07
  label_05 : {
    aot_vmfetch(0x00010400);
    setobjs2s(L, ra, RB(i));
  }
  
  // 7	[67]	MOVE     	9 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_08
  label_06 : {
    aot_vmfetch(0x00020480);
    setobjs2s(L, ra, RB(i));
  }
  
  // 8	[67]	CALL     	7 3 1	; 2 in 0 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_09
  label_07 : {
    aot_vmfetch(0x010303c2);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 9	[66]	FORLOOP  	3 5	; to 5
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 9)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_08 : {
    aot_vmfetch(0x000281c7);
    if (ttisinteger(s2v(ra + 2))) {  /* integer loop? */
      lua_Unsigned count = l_castS2U(ivalue(s2v(ra + 1)));
      if (count > 0) {  /* still more iterations? */
        lua_Integer step = ivalue(s2v(ra + 2));
        lua_Integer idx = ivalue(s2v(ra));  /* internal index */
        chgivalue(s2v(ra + 1), count - 1);  /* update counter */
        idx = intop(+, idx, step);  /* add step to index */
        chgivalue(s2v(ra), idx);  /* update internal index */
        setivalue(s2v(ra + 3), idx);  /* and control variable */
        goto label_04; /* jump back */
      }
    }
    else {  /* floating loop */
      lua_Number step = fltvalue(s2v(ra + 2));
      lua_Number limit = fltvalue(s2v(ra + 1));
      lua_Number idx = fltvalue(s2v(ra));
      idx = luai_numadd(L, idx, step);  /* increment index */
      if (luai_numlt(0, step) ? luai_numle(idx, limit)
                              : luai_numle(limit, idx)) {
        chgfltvalue(s2v(ra), idx);  /* update internal index */
        setfltvalue(s2v(ra + 3), idx);  /* and control variable */
        goto label_04; /* jump back */
      }
    }
    updatetrap(ci);  /* allows a signal to break the loop */
  }
  
  // 10	[69]	RETURN0  	
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 10)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_09 : {
    aot_vmfetch(0x000101c5);
    if (L->hookmask) {
      L->top = ra;
      halfProtectNT(luaD_poscall(L, ci, 0));  /* no hurry... */
    }
    else {  /* do the 'poscall' here */
      int nres = ci->nresults;
      L->ci = ci->previous;  /* back to caller */
      L->top = base - 1;
      while (nres-- > 0)
        setnilvalue(s2v(L->top++));  /* all results are nil */
    }
    return;
  }
  
}
 
// source = @benchmarks/nbody/lua.lua
// lines: 71 - 90
static
void magic_implementation_05(lua_State *L, CallInfo *ci)
{
  LClosure *cl;
  TValue *k;
  StkId base;
  const Instruction *saved_pc;
  int trap;
  
 tailcall:
  trap = L->hookmask;
  cl = clLvalue(s2v(ci->func));
  k = cl->p->k;
  saved_pc = ci->u.l.savedpc;  /*no explicit program counter*/ 
  if (trap) {
    if (cl->p->is_vararg)
      trap = 0;  /* hooks will start after VARARGPREP instruction */
    else if (saved_pc == cl->p->code) /*first instruction (not resuming)?*/
      luaD_hookcall(L, ci);
    ci->u.l.trap = 1;  /* there may be other hooks */
  }
  base = ci->func + 1;
  /* main loop of interpreter */
  Instruction *function_code = cl->p->code;
  Instruction i;
  StkId ra;
  (void) function_code;
  (void) i;
  (void) ra;
 
  // 1	[72]	LEN      	1 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 1)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_02
  label_00 : {
    aot_vmfetch(0x000000b2);
    Protect(luaV_objlen(L, ra, vRB(i)));
  }
  
  // 2	[73]	LOADF    	2 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x7fff8102);
    int b = GETARG_sBx(i);
    setfltvalue(s2v(ra), cast_num(b));
  }
  
  // 3	[74]	LOADI    	3 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x80000181);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }
  
  // 4	[74]	MOVE     	4 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0x00010200);
    setobjs2s(L, ra, RB(i));
  }
  
  // 5	[74]	LOADI    	5 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x80000281);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }
  
  // 6	[74]	FORPREP  	3 61	; to 68
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_07
  label_05 : {
    aot_vmfetch(0x001e81c8);
    TValue *pinit = s2v(ra);
    TValue *plimit = s2v(ra + 1);
    TValue *pstep = s2v(ra + 2);
    savestate(L, ci);  /* in case of errors */
    if (ttisinteger(pinit) && ttisinteger(pstep)) { /* integer loop? */
      lua_Integer init = ivalue(pinit);
      lua_Integer step = ivalue(pstep);
      lua_Integer limit;
      if (step == 0)
        luaG_runerror(L, "'for' step is zero");
      setivalue(s2v(ra + 3), init);  /* control variable */
      if (forlimit(L, init, plimit, &limit, step))
        goto label_68; /* skip the loop */
      else {  /* prepare loop counter */
        lua_Unsigned count;
        if (step > 0) {  /* ascending loop? */
          count = l_castS2U(limit) - l_castS2U(init);
          if (step != 1)  /* avoid division in the too common case */
            count /= l_castS2U(step);
        }
        else {  /* step < 0; descending loop */
          count = l_castS2U(init) - l_castS2U(limit);
          /* 'step+1' avoids negating 'mininteger' */
          count /= l_castS2U(-(step + 1)) + 1u;
        }
        /* store the counter in place of the limit (which won't be
           needed anymore */
        setivalue(plimit, l_castU2S(count));
      }
    }
    else {  /* try making all values floats */
      lua_Number init; lua_Number limit; lua_Number step;
      if (unlikely(!tonumber(plimit, &limit)))
        luaG_forerror(L, plimit, "limit");
      if (unlikely(!tonumber(pstep, &step)))
        luaG_forerror(L, pstep, "step");
      if (unlikely(!tonumber(pinit, &init)))
        luaG_forerror(L, pinit, "initial value");
      if (step == 0)
        luaG_runerror(L, "'for' step is zero");
      if (luai_numlt(0, step) ? luai_numlt(limit, init)
                               : luai_numlt(init, limit))
        goto label_68; /* skip the loop */
      else {
        /* make sure internal values are all float */
        setfltvalue(plimit, limit);
        setfltvalue(pstep, step);
        setfltvalue(s2v(ra), init);  /* internal index */
        setfltvalue(s2v(ra + 3), init);  /* control variable */
      }
    }
  }
  
  // 7	[75]	GETTABLE 	7 0 6
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_08
  label_06 : {
    aot_vmfetch(0x0600038a);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = vRC(i);
    lua_Unsigned n;
    if (ttisinteger(rc)  /* fast track for integers? */
        ? (cast_void(n = ivalue(rc)), luaV_fastgeti(L, rb, n, slot))
        : luaV_fastget(L, rb, rc, slot, luaH_get)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 8	[76]	GETFIELD 	8 7 0	; "vx"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_09
  label_07 : {
    aot_vmfetch(0x0007040c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 9	[77]	GETFIELD 	9 7 1	; "vy"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 9)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_10
  label_08 : {
    aot_vmfetch(0x0107048c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 10	[78]	GETFIELD 	10 7 2	; "vz"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 10)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_11
  label_09 : {
    aot_vmfetch(0x0207050c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 11	[79]	GETFIELD 	11 7 3	; "mass"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 11)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_12
  label_10 : {
    aot_vmfetch(0x0307058c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 12	[79]	MULK     	11 11 4 	; 0.5
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 12)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_13
  label_11 : {
    aot_vmfetch(0x040b0596);
    op_arithK(L, l_muli, luai_nummul, GETARG_k(i));
  }
  
  // 13	[79]	MMBINK   	11 4 8	; __mul 0.5
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 13)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_14
  label_12 : {
    aot_vmfetch(0x080485ae);
    Instruction pi = 0x040b0596;  /* original arith. expression */
    TValue *imm = KB(i);
    TMS tm = (TMS)GETARG_C(i);
    int flip = GETARG_k(i);
    StkId result = RA(pi);
    Protect(luaT_trybinassocTM(L, s2v(ra), imm, flip, result, tm));
  }
  
  // 14	[79]	MUL      	12 8 8
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 14)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_15
  label_13 : {
    aot_vmfetch(0x08080622);
    op_arith(L, l_muli, luai_nummul);
  }
  
  // 15	[79]	MMBIN    	8 8 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 15)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_16
  label_14 : {
    aot_vmfetch(0x0808042c);
    Instruction pi = 0x08080622; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 16	[79]	MUL      	13 9 9
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 16)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_17
  label_15 : {
    aot_vmfetch(0x090906a2);
    op_arith(L, l_muli, luai_nummul);
  }
  
  // 17	[79]	MMBIN    	9 9 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 17)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_18
  label_16 : {
    aot_vmfetch(0x080904ac);
    Instruction pi = 0x090906a2; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 18	[79]	ADD      	12 12 13
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 18)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_19
  label_17 : {
    aot_vmfetch(0x0d0c0620);
    op_arith(L, l_addi, luai_numadd);
  }
  
  // 19	[79]	MMBIN    	12 13 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 19)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_20
  label_18 : {
    aot_vmfetch(0x060d062c);
    Instruction pi = 0x0d0c0620; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 20	[79]	MUL      	13 10 10
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 20)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_21
  label_19 : {
    aot_vmfetch(0x0a0a06a2);
    op_arith(L, l_muli, luai_nummul);
  }
  
  // 21	[79]	MMBIN    	10 10 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 21)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_22
  label_20 : {
    aot_vmfetch(0x080a052c);
    Instruction pi = 0x0a0a06a2; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 22	[79]	ADD      	12 12 13
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 22)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_23
  label_21 : {
    aot_vmfetch(0x0d0c0620);
    op_arith(L, l_addi, luai_numadd);
  }
  
  // 23	[79]	MMBIN    	12 13 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 23)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_24
  label_22 : {
    aot_vmfetch(0x060d062c);
    Instruction pi = 0x0d0c0620; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 24	[79]	MUL      	11 11 12
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 24)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_25
  label_23 : {
    aot_vmfetch(0x0c0b05a2);
    op_arith(L, l_muli, luai_nummul);
  }
  
  // 25	[79]	MMBIN    	11 12 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 25)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_26
  label_24 : {
    aot_vmfetch(0x080c05ac);
    Instruction pi = 0x0c0b05a2; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 26	[79]	ADD      	2 2 11
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 26)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_27
  label_25 : {
    aot_vmfetch(0x0b020120);
    op_arith(L, l_addi, luai_numadd);
  }
  
  // 27	[79]	MMBIN    	2 11 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 27)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_28
  label_26 : {
    aot_vmfetch(0x060b012c);
    Instruction pi = 0x0b020120; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 28	[80]	ADDI     	11 6 1 
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 28)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_29
  label_27 : {
    aot_vmfetch(0x80060593);
    op_arithI(L, l_addi, luai_numadd, TM_ADD, GETARG_k(i));
  }
  
  // 29	[80]	MMBINI   	6 1 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 29)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_30
  label_28 : {
    aot_vmfetch(0x0680032d);
    Instruction pi = 0x80060593;  /* original arith. expression */
    int imm = GETARG_sB(i);
    TMS tm = (TMS)GETARG_C(i);
    int flip = GETARG_k(i);
    StkId result = RA(pi);
    Protect(luaT_trybiniTM(L, s2v(ra), imm, flip, result, tm));
  }
  
  // 30	[80]	MOVE     	12 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 30)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_31
  label_29 : {
    aot_vmfetch(0x00010600);
    setobjs2s(L, ra, RB(i));
  }
  
  // 31	[80]	LOADI    	13 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 31)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_32
  label_30 : {
    aot_vmfetch(0x80000681);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }
  
  // 32	[80]	FORPREP  	11 34	; to 67
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 32)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_33
  label_31 : {
    aot_vmfetch(0x001105c8);
    TValue *pinit = s2v(ra);
    TValue *plimit = s2v(ra + 1);
    TValue *pstep = s2v(ra + 2);
    savestate(L, ci);  /* in case of errors */
    if (ttisinteger(pinit) && ttisinteger(pstep)) { /* integer loop? */
      lua_Integer init = ivalue(pinit);
      lua_Integer step = ivalue(pstep);
      lua_Integer limit;
      if (step == 0)
        luaG_runerror(L, "'for' step is zero");
      setivalue(s2v(ra + 3), init);  /* control variable */
      if (forlimit(L, init, plimit, &limit, step))
        goto label_67; /* skip the loop */
      else {  /* prepare loop counter */
        lua_Unsigned count;
        if (step > 0) {  /* ascending loop? */
          count = l_castS2U(limit) - l_castS2U(init);
          if (step != 1)  /* avoid division in the too common case */
            count /= l_castS2U(step);
        }
        else {  /* step < 0; descending loop */
          count = l_castS2U(init) - l_castS2U(limit);
          /* 'step+1' avoids negating 'mininteger' */
          count /= l_castS2U(-(step + 1)) + 1u;
        }
        /* store the counter in place of the limit (which won't be
           needed anymore */
        setivalue(plimit, l_castU2S(count));
      }
    }
    else {  /* try making all values floats */
      lua_Number init; lua_Number limit; lua_Number step;
      if (unlikely(!tonumber(plimit, &limit)))
        luaG_forerror(L, plimit, "limit");
      if (unlikely(!tonumber(pstep, &step)))
        luaG_forerror(L, pstep, "step");
      if (unlikely(!tonumber(pinit, &init)))
        luaG_forerror(L, pinit, "initial value");
      if (step == 0)
        luaG_runerror(L, "'for' step is zero");
      if (luai_numlt(0, step) ? luai_numlt(limit, init)
                               : luai_numlt(init, limit))
        goto label_67; /* skip the loop */
      else {
        /* make sure internal values are all float */
        setfltvalue(plimit, limit);
        setfltvalue(pstep, step);
        setfltvalue(s2v(ra), init);  /* internal index */
        setfltvalue(s2v(ra + 3), init);  /* control variable */
      }
    }
  }
  
  // 33	[81]	GETTABLE 	15 0 14
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 33)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_34
  label_32 : {
    aot_vmfetch(0x0e00078a);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = vRC(i);
    lua_Unsigned n;
    if (ttisinteger(rc)  /* fast track for integers? */
        ? (cast_void(n = ivalue(rc)), luaV_fastgeti(L, rb, n, slot))
        : luaV_fastget(L, rb, rc, slot, luaH_get)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 34	[82]	GETFIELD 	16 7 5	; "x"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 34)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_35
  label_33 : {
    aot_vmfetch(0x0507080c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 35	[82]	GETFIELD 	17 15 5	; "x"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 35)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_36
  label_34 : {
    aot_vmfetch(0x050f088c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 36	[82]	SUB      	16 16 17
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 36)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_37
  label_35 : {
    aot_vmfetch(0x11100821);
    op_arith(L, l_subi, luai_numsub);
  }
  
  // 37	[82]	MMBIN    	16 17 7	; __sub
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 37)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_38
  label_36 : {
    aot_vmfetch(0x0711082c);
    Instruction pi = 0x11100821; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 38	[83]	GETFIELD 	17 7 6	; "y"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 38)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_39
  label_37 : {
    aot_vmfetch(0x0607088c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 39	[83]	GETFIELD 	18 15 6	; "y"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 39)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_40
  label_38 : {
    aot_vmfetch(0x060f090c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 40	[83]	SUB      	17 17 18
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 40)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_41
  label_39 : {
    aot_vmfetch(0x121108a1);
    op_arith(L, l_subi, luai_numsub);
  }
  
  // 41	[83]	MMBIN    	17 18 7	; __sub
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 41)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_42
  label_40 : {
    aot_vmfetch(0x071208ac);
    Instruction pi = 0x121108a1; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 42	[84]	GETFIELD 	18 7 7	; "z"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 42)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_43
  label_41 : {
    aot_vmfetch(0x0707090c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 43	[84]	GETFIELD 	19 15 7	; "z"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 43)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_44
  label_42 : {
    aot_vmfetch(0x070f098c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 44	[84]	SUB      	18 18 19
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 44)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_45
  label_43 : {
    aot_vmfetch(0x13120921);
    op_arith(L, l_subi, luai_numsub);
  }
  
  // 45	[84]	MMBIN    	18 19 7	; __sub
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 45)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_46
  label_44 : {
    aot_vmfetch(0x0713092c);
    Instruction pi = 0x13120921; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 46	[85]	GETTABUP 	19 0 8	; _ENV "math"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 46)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_47
  label_45 : {
    aot_vmfetch(0x08000989);
    const TValue *slot;
    TValue *upval = cl->upvals[GETARG_B(i)]->v;
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, upval, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, upval, rc, ra, slot));
  }
  
  // 47	[85]	GETFIELD 	19 19 9	; "sqrt"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 47)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_48
  label_46 : {
    aot_vmfetch(0x0913098c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 48	[85]	MUL      	20 16 16
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 48)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_49
  label_47 : {
    aot_vmfetch(0x10100a22);
    op_arith(L, l_muli, luai_nummul);
  }
  
  // 49	[85]	MMBIN    	16 16 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 49)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_50
  label_48 : {
    aot_vmfetch(0x0810082c);
    Instruction pi = 0x10100a22; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 50	[85]	MUL      	21 17 17
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 50)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_51
  label_49 : {
    aot_vmfetch(0x11110aa2);
    op_arith(L, l_muli, luai_nummul);
  }
  
  // 51	[85]	MMBIN    	17 17 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 51)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_52
  label_50 : {
    aot_vmfetch(0x081108ac);
    Instruction pi = 0x11110aa2; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 52	[85]	ADD      	20 20 21
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 52)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_53
  label_51 : {
    aot_vmfetch(0x15140a20);
    op_arith(L, l_addi, luai_numadd);
  }
  
  // 53	[85]	MMBIN    	20 21 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 53)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_54
  label_52 : {
    aot_vmfetch(0x06150a2c);
    Instruction pi = 0x15140a20; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 54	[85]	MUL      	21 18 18
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 54)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_55
  label_53 : {
    aot_vmfetch(0x12120aa2);
    op_arith(L, l_muli, luai_nummul);
  }
  
  // 55	[85]	MMBIN    	18 18 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 55)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_56
  label_54 : {
    aot_vmfetch(0x0812092c);
    Instruction pi = 0x12120aa2; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 56	[85]	ADD      	20 20 21
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 56)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_57
  label_55 : {
    aot_vmfetch(0x15140a20);
    op_arith(L, l_addi, luai_numadd);
  }
  
  // 57	[85]	MMBIN    	20 21 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 57)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_58
  label_56 : {
    aot_vmfetch(0x06150a2c);
    Instruction pi = 0x15140a20; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 58	[85]	CALL     	19 2 2	; 1 in 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 58)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_59
  label_57 : {
    aot_vmfetch(0x020209c2);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 59	[86]	GETFIELD 	20 7 3	; "mass"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 59)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_60
  label_58 : {
    aot_vmfetch(0x03070a0c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 60	[86]	GETFIELD 	21 15 3	; "mass"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 60)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_61
  label_59 : {
    aot_vmfetch(0x030f0a8c);
    const TValue *slot;
    TValue *rb = vRB(i);
    TValue *rc = KC(i);
    TString *key = tsvalue(rc);  /* key must be a string */
    if (luaV_fastget(L, rb, key, slot, luaH_getshortstr)) {
      setobj2s(L, ra, slot);
    }
    else
      Protect(luaV_finishget(L, rb, rc, ra, slot));
  }
  
  // 61	[86]	MUL      	20 20 21
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 61)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_62
  label_60 : {
    aot_vmfetch(0x15140a22);
    op_arith(L, l_muli, luai_nummul);
  }
  
  // 62	[86]	MMBIN    	20 21 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 62)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_63
  label_61 : {
    aot_vmfetch(0x08150a2c);
    Instruction pi = 0x15140a22; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 63	[86]	DIV      	20 20 19
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 63)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_64
  label_62 : {
    aot_vmfetch(0x13140a25);
    op_arithf(L, luai_numdiv);
  }
  
  // 64	[86]	MMBIN    	20 19 11	; __div
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 64)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_65
  label_63 : {
    aot_vmfetch(0x0b130a2c);
    Instruction pi = 0x13140a25; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 65	[86]	SUB      	2 2 20
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 65)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_66
  label_64 : {
    aot_vmfetch(0x14020121);
    op_arith(L, l_subi, luai_numsub);
  }
  
  // 66	[86]	MMBIN    	2 20 7	; __sub
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 66)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_67
  label_65 : {
    aot_vmfetch(0x0714012c);
    Instruction pi = 0x14020121; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 67	[80]	FORLOOP  	11 35	; to 33
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 67)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_68
  label_66 : {
    aot_vmfetch(0x001185c7);
    if (ttisinteger(s2v(ra + 2))) {  /* integer loop? */
      lua_Unsigned count = l_castS2U(ivalue(s2v(ra + 1)));
      if (count > 0) {  /* still more iterations? */
        lua_Integer step = ivalue(s2v(ra + 2));
        lua_Integer idx = ivalue(s2v(ra));  /* internal index */
        chgivalue(s2v(ra + 1), count - 1);  /* update counter */
        idx = intop(+, idx, step);  /* add step to index */
        chgivalue(s2v(ra), idx);  /* update internal index */
        setivalue(s2v(ra + 3), idx);  /* and control variable */
        goto label_32; /* jump back */
      }
    }
    else {  /* floating loop */
      lua_Number step = fltvalue(s2v(ra + 2));
      lua_Number limit = fltvalue(s2v(ra + 1));
      lua_Number idx = fltvalue(s2v(ra));
      idx = luai_numadd(L, idx, step);  /* increment index */
      if (luai_numlt(0, step) ? luai_numle(idx, limit)
                              : luai_numle(limit, idx)) {
        chgfltvalue(s2v(ra), idx);  /* update internal index */
        setfltvalue(s2v(ra + 3), idx);  /* and control variable */
        goto label_32; /* jump back */
      }
    }
    updatetrap(ci);  /* allows a signal to break the loop */
  }
  
  // 68	[74]	FORLOOP  	3 62	; to 7
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 68)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_69
  label_67 : {
    aot_vmfetch(0x001f01c7);
    if (ttisinteger(s2v(ra + 2))) {  /* integer loop? */
      lua_Unsigned count = l_castS2U(ivalue(s2v(ra + 1)));
      if (count > 0) {  /* still more iterations? */
        lua_Integer step = ivalue(s2v(ra + 2));
        lua_Integer idx = ivalue(s2v(ra));  /* internal index */
        chgivalue(s2v(ra + 1), count - 1);  /* update counter */
        idx = intop(+, idx, step);  /* add step to index */
        chgivalue(s2v(ra), idx);  /* update internal index */
        setivalue(s2v(ra + 3), idx);  /* and control variable */
        goto label_06; /* jump back */
      }
    }
    else {  /* floating loop */
      lua_Number step = fltvalue(s2v(ra + 2));
      lua_Number limit = fltvalue(s2v(ra + 1));
      lua_Number idx = fltvalue(s2v(ra));
      idx = luai_numadd(L, idx, step);  /* increment index */
      if (luai_numlt(0, step) ? luai_numle(idx, limit)
                              : luai_numle(limit, idx)) {
        chgfltvalue(s2v(ra), idx);  /* update internal index */
        setfltvalue(s2v(ra + 3), idx);  /* and control variable */
        goto label_06; /* jump back */
      }
    }
    updatetrap(ci);  /* allows a signal to break the loop */
  }
  
  // 69	[89]	RETURN1  	2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 69)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_68 : {
    aot_vmfetch(0x00020146);
    if (L->hookmask) {
      L->top = ra + 1;
      halfProtectNT(luaD_poscall(L, ci, 1));  /* no hurry... */
    }
    else {  /* do the 'poscall' here */
      int nres = ci->nresults;
      L->ci = ci->previous;  /* back to caller */
      if (nres == 0)
        L->top = base - 1;  /* asked for no results */
      else {
        setobjs2s(L, base - 1, ra);  /* at least this result */
        L->top = base;
        while (--nres > 0)  /* complete missing results */
          setnilvalue(s2v(L->top++));
      }
    }
    return;
  }
  
  // 70	[90]	RETURN0  	
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 70)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_69 : {
    aot_vmfetch(0x000101c5);
    if (L->hookmask) {
      L->top = ra;
      halfProtectNT(luaD_poscall(L, ci, 0));  /* no hurry... */
    }
    else {  /* do the 'poscall' here */
      int nres = ci->nresults;
      L->ci = ci->previous;  /* back to caller */
      L->top = base - 1;
      while (nres-- > 0)
        setnilvalue(s2v(L->top++));  /* all results are nil */
    }
    return;
  }
  
}
 
static AotCompiledFunction LUA_AOT_FUNCTIONS[] = {
  magic_implementation_00,
  magic_implementation_01,
  magic_implementation_02,
  magic_implementation_03,
  magic_implementation_04,
  magic_implementation_05,
  NULL
};
 
static const char LUA_AOT_MODULE_SOURCE_CODE[] = {
  108, 111,  99,  97, 108,  32, 102, 117, 110,  99, 116, 105, 111, 110,  32, 110, 
  101, 119,  95,  98, 111, 100, 121,  40, 120,  44,  32, 121,  44,  32, 122,  44, 
   32, 118, 120,  44,  32, 118, 121,  44,  32, 118, 122,  44,  32, 109,  97, 115, 
  115,  41,  10,  32,  32,  32,  32, 114, 101, 116, 117, 114, 110,  32, 123,  10, 
   32,  32,  32,  32,  32,  32,  32,  32, 120,  32,  61,  32, 120,  44,  10,  32, 
   32,  32,  32,  32,  32,  32,  32, 121,  32,  61,  32, 121,  44,  10,  32,  32, 
   32,  32,  32,  32,  32,  32, 122,  32,  61,  32, 122,  44,  10,  32,  32,  32, 
   32,  32,  32,  32,  32, 118, 120,  32,  61,  32, 118, 120,  44,  10,  32,  32, 
   32,  32,  32,  32,  32,  32, 118, 121,  32,  61,  32, 118, 121,  44,  10,  32, 
   32,  32,  32,  32,  32,  32,  32, 118, 122,  32,  61,  32, 118, 122,  44,  10, 
   32,  32,  32,  32,  32,  32,  32,  32, 109,  97, 115, 115,  32,  61,  32, 109, 
   97, 115, 115,  44,  10,  32,  32,  32,  32, 125,  10, 101, 110, 100,  10,  10, 
  108, 111,  99,  97, 108,  32, 102, 117, 110,  99, 116, 105, 111, 110,  32, 111, 
  102, 102, 115, 101, 116,  95, 109, 111, 109, 101, 110, 116, 117, 109,  40,  98, 
  111, 100, 105, 101, 115,  41,  10,  32,  32,  32,  32, 108, 111,  99,  97, 108, 
   32, 110,  32,  61,  32,  35,  98, 111, 100, 105, 101, 115,  10,  32,  32,  32, 
   32, 108, 111,  99,  97, 108,  32, 112, 120,  32,  61,  32,  48,  46,  48,  10, 
   32,  32,  32,  32, 108, 111,  99,  97, 108,  32, 112, 121,  32,  61,  32,  48, 
   46,  48,  10,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32, 112, 122,  32, 
   61,  32,  48,  46,  48,  10,  32,  32,  32,  32, 102, 111, 114,  32, 105,  61, 
   32,  49,  44,  32, 110,  32, 100, 111,  10,  32,  32,  32,  32,  32,  32, 108, 
  111,  99,  97, 108,  32,  98, 105,  32,  61,  32,  98, 111, 100, 105, 101, 115, 
   91, 105,  93,  10,  32,  32,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32, 
   98, 105, 109,  32,  61,  32,  98, 105,  46, 109,  97, 115, 115,  10,  32,  32, 
   32,  32,  32,  32, 112, 120,  32,  61,  32, 112, 120,  32,  43,  32,  40,  98, 
  105,  46, 118, 120,  32,  42,  32,  98, 105, 109,  41,  10,  32,  32,  32,  32, 
   32,  32, 112, 121,  32,  61,  32, 112, 121,  32,  43,  32,  40,  98, 105,  46, 
  118, 121,  32,  42,  32,  98, 105, 109,  41,  10,  32,  32,  32,  32,  32,  32, 
  112, 122,  32,  61,  32, 112, 122,  32,  43,  32,  40,  98, 105,  46, 118, 122, 
   32,  42,  32,  98, 105, 109,  41,  10,  32,  32,  32,  32, 101, 110, 100,  10, 
   10,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32, 115, 117, 110,  32,  61, 
   32,  98, 111, 100, 105, 101, 115,  91,  49,  93,  10,  32,  32,  32,  32, 108, 
  111,  99,  97, 108,  32, 115, 111, 108,  97, 114,  95, 109,  97, 115, 115,  32, 
   61,  32, 115, 117, 110,  46, 109,  97, 115, 115,  10,  32,  32,  32,  32, 115, 
  117, 110,  46, 118, 120,  32,  61,  32, 115, 117, 110,  46, 118, 120,  32,  45, 
   32, 112, 120,  32,  47,  32, 115, 111, 108,  97, 114,  95, 109,  97, 115, 115, 
   10,  32,  32,  32,  32, 115, 117, 110,  46, 118, 121,  32,  61,  32, 115, 117, 
  110,  46, 118, 121,  32,  45,  32, 112, 121,  32,  47,  32, 115, 111, 108,  97, 
  114,  95, 109,  97, 115, 115,  10,  32,  32,  32,  32, 115, 117, 110,  46, 118, 
  122,  32,  61,  32, 115, 117, 110,  46, 118, 122,  32,  45,  32, 112, 122,  32, 
   47,  32, 115, 111, 108,  97, 114,  95, 109,  97, 115, 115,  10, 101, 110, 100, 
   10,  10, 108, 111,  99,  97, 108,  32, 102, 117, 110,  99, 116, 105, 111, 110, 
   32,  97, 100, 118,  97, 110,  99, 101,  40,  98, 111, 100, 105, 101, 115,  44, 
   32, 100, 116,  41,  10,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32, 110, 
   32,  61,  32,  35,  98, 111, 100, 105, 101, 115,  10,  32,  32,  32,  32, 102, 
  111, 114,  32, 105,  32,  61,  32,  49,  44,  32, 110,  32, 100, 111,  10,  32, 
   32,  32,  32,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32,  98, 105,  32, 
   61,  32,  98, 111, 100, 105, 101, 115,  91, 105,  93,  10,  32,  32,  32,  32, 
   32,  32,  32,  32, 102, 111, 114,  32, 106,  61, 105,  43,  49,  44, 110,  32, 
  100, 111,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32, 108, 111,  99, 
   97, 108,  32,  98, 106,  32,  61,  32,  98, 111, 100, 105, 101, 115,  91, 106, 
   93,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32, 108, 111,  99,  97, 
  108,  32, 100, 120,  32,  61,  32,  98, 105,  46, 120,  32,  45,  32,  98, 106, 
   46, 120,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32, 108, 111,  99, 
   97, 108,  32, 100, 121,  32,  61,  32,  98, 105,  46, 121,  32,  45,  32,  98, 
  106,  46, 121,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32, 108, 111, 
   99,  97, 108,  32, 100, 122,  32,  61,  32,  98, 105,  46, 122,  32,  45,  32, 
   98, 106,  46, 122,  10,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32, 
  108, 111,  99,  97, 108,  32, 100, 105, 115, 116,  32,  61,  32, 109,  97, 116, 
  104,  46, 115, 113, 114, 116,  40, 100, 120,  42, 100, 120,  32,  43,  32, 100, 
  121,  42, 100, 121,  32,  43,  32, 100, 122,  42, 100, 122,  41,  10,  32,  32, 
   32,  32,  32,  32,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32, 109,  97, 
  103,  32,  61,  32, 100, 116,  32,  47,  32,  40, 100, 105, 115, 116,  32,  42, 
   32, 100, 105, 115, 116,  32,  42,  32, 100, 105, 115, 116,  41,  10,  10,  32, 
   32,  32,  32,  32,  32,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32,  98, 
  106, 109,  32,  61,  32,  98, 106,  46, 109,  97, 115, 115,  32,  42,  32, 109, 
   97, 103,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  98, 105,  46, 
  118, 120,  32,  61,  32,  98, 105,  46, 118, 120,  32,  45,  32,  40, 100, 120, 
   32,  42,  32,  98, 106, 109,  41,  10,  32,  32,  32,  32,  32,  32,  32,  32, 
   32,  32,  98, 105,  46, 118, 121,  32,  61,  32,  98, 105,  46, 118, 121,  32, 
   45,  32,  40, 100, 121,  32,  42,  32,  98, 106, 109,  41,  10,  32,  32,  32, 
   32,  32,  32,  32,  32,  32,  32,  98, 105,  46, 118, 122,  32,  61,  32,  98, 
  105,  46, 118, 122,  32,  45,  32,  40, 100, 122,  32,  42,  32,  98, 106, 109, 
   41,  10,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32, 108, 111,  99, 
   97, 108,  32,  98, 105, 109,  32,  61,  32,  98, 105,  46, 109,  97, 115, 115, 
   32,  42,  32, 109,  97, 103,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32, 
   32,  98, 106,  46, 118, 120,  32,  61,  32,  98, 106,  46, 118, 120,  32,  43, 
   32,  40, 100, 120,  32,  42,  32,  98, 105, 109,  41,  10,  32,  32,  32,  32, 
   32,  32,  32,  32,  32,  32,  98, 106,  46, 118, 121,  32,  61,  32,  98, 106, 
   46, 118, 121,  32,  43,  32,  40, 100, 121,  32,  42,  32,  98, 105, 109,  41, 
   10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  98, 106,  46, 118, 122, 
   32,  61,  32,  98, 106,  46, 118, 122,  32,  43,  32,  40, 100, 122,  32,  42, 
   32,  98, 105, 109,  41,  10,  32,  32,  32,  32,  32,  32,  32,  32, 101, 110, 
  100,  10,  32,  32,  32,  32, 101, 110, 100,  10,  32,  32,  32,  32, 102, 111, 
  114,  32, 105,  32,  61,  32,  49,  44,  32, 110,  32, 100, 111,  10,  32,  32, 
   32,  32,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32,  98, 105,  32,  61, 
   32,  98, 111, 100, 105, 101, 115,  91, 105,  93,  10,  32,  32,  32,  32,  32, 
   32,  32,  32,  98, 105,  46, 120,  32,  61,  32,  98, 105,  46, 120,  32,  43, 
   32, 100, 116,  32,  42,  32,  98, 105,  46, 118, 120,  10,  32,  32,  32,  32, 
   32,  32,  32,  32,  98, 105,  46, 121,  32,  61,  32,  98, 105,  46, 121,  32, 
   43,  32, 100, 116,  32,  42,  32,  98, 105,  46, 118, 121,  10,  32,  32,  32, 
   32,  32,  32,  32,  32,  98, 105,  46, 122,  32,  61,  32,  98, 105,  46, 122, 
   32,  43,  32, 100, 116,  32,  42,  32,  98, 105,  46, 118, 122,  10,  32,  32, 
   32,  32, 101, 110, 100,  10, 101, 110, 100,  10,  10, 108, 111,  99,  97, 108, 
   32, 102, 117, 110,  99, 116, 105, 111, 110,  32,  97, 100, 118,  97, 110,  99, 
  101,  95, 109, 117, 108, 116, 105, 112, 108, 101,  95, 115, 116, 101, 112, 115, 
   40, 110, 115, 116, 101, 112, 115,  44,  32,  98, 111, 100, 105, 101, 115,  44, 
   32, 100, 116,  41,  10,  32,  32,  32,  32, 102, 111, 114,  32,  95,  32,  61, 
   32,  49,  44,  32, 110, 115, 116, 101, 112, 115,  32, 100, 111,  10,  32,  32, 
   32,  32,  32,  32,  32,  32,  97, 100, 118,  97, 110,  99, 101,  40,  98, 111, 
  100, 105, 101, 115,  44,  32, 100, 116,  41,  10,  32,  32,  32,  32, 101, 110, 
  100,  10, 101, 110, 100,  10,  10, 108, 111,  99,  97, 108,  32, 102, 117, 110, 
   99, 116, 105, 111, 110,  32, 101, 110, 101, 114, 103, 121,  40,  98, 111, 100, 
  105, 101, 115,  41,  10,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32, 110, 
   32,  61,  32,  35,  98, 111, 100, 105, 101, 115,  10,  32,  32,  32,  32, 108, 
  111,  99,  97, 108,  32, 101,  32,  61,  32,  48,  46,  48,  10,  32,  32,  32, 
   32, 102, 111, 114,  32, 105,  32,  61,  32,  49,  44,  32, 110,  32, 100, 111, 
   10,  32,  32,  32,  32,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32,  98, 
  105,  32,  61,  32,  98, 111, 100, 105, 101, 115,  91, 105,  93,  10,  32,  32, 
   32,  32,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32, 118, 120,  32,  61, 
   32,  98, 105,  46, 118, 120,  10,  32,  32,  32,  32,  32,  32,  32,  32, 108, 
  111,  99,  97, 108,  32, 118, 121,  32,  61,  32,  98, 105,  46, 118, 121,  10, 
   32,  32,  32,  32,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32, 118, 122, 
   32,  61,  32,  98, 105,  46, 118, 122,  10,  32,  32,  32,  32,  32,  32,  32, 
   32, 101,  32,  61,  32, 101,  32,  43,  32,  48,  46,  53,  32,  42,  32,  98, 
  105,  46, 109,  97, 115, 115,  32,  42,  32,  40, 118, 120,  42, 118, 120,  32, 
   43,  32, 118, 121,  42, 118, 121,  32,  43,  32, 118, 122,  42, 118, 122,  41, 
   10,  32,  32,  32,  32,  32,  32,  32,  32, 102, 111, 114,  32, 106,  32,  61, 
   32, 105,  43,  49,  44,  32, 110,  32, 100, 111,  10,  32,  32,  32,  32,  32, 
   32,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32,  98, 106,  32,  61,  32, 
   98, 111, 100, 105, 101, 115,  91, 106,  93,  10,  32,  32,  32,  32,  32,  32, 
   32,  32,  32,  32, 108, 111,  99,  97, 108,  32, 100, 120,  32,  61,  32,  98, 
  105,  46, 120,  45,  98, 106,  46, 120,  10,  32,  32,  32,  32,  32,  32,  32, 
   32,  32,  32, 108, 111,  99,  97, 108,  32, 100, 121,  32,  61,  32,  98, 105, 
   46, 121,  45,  98, 106,  46, 121,  10,  32,  32,  32,  32,  32,  32,  32,  32, 
   32,  32, 108, 111,  99,  97, 108,  32, 100, 122,  32,  61,  32,  98, 105,  46, 
  122,  45,  98, 106,  46, 122,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32, 
   32, 108, 111,  99,  97, 108,  32, 100, 105, 115, 116,  97, 110,  99, 101,  32, 
   61,  32, 109,  97, 116, 104,  46, 115, 113, 114, 116,  40, 100, 120,  42, 100, 
  120,  32,  43,  32, 100, 121,  42, 100, 121,  32,  43,  32, 100, 122,  42, 100, 
  122,  41,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32, 101,  32,  61, 
   32, 101,  32,  45,  32,  40,  98, 105,  46, 109,  97, 115, 115,  32,  42,  32, 
   98, 106,  46, 109,  97, 115, 115,  41,  32,  47,  32, 100, 105, 115, 116,  97, 
  110,  99, 101,  10,  32,  32,  32,  32,  32,  32,  32,  32, 101, 110, 100,  10, 
   32,  32,  32,  32, 101, 110, 100,  10,  32,  32,  32,  32, 114, 101, 116, 117, 
  114, 110,  32, 101,  10, 101, 110, 100,  10,  10, 114, 101, 116, 117, 114, 110, 
   32, 123,  10,  32,  32,  32,  32, 110, 101, 119,  95,  98, 111, 100, 121,  32, 
   61,  32, 110, 101, 119,  95,  98, 111, 100, 121,  44,  10,  32,  32,  32,  32, 
  111, 102, 102, 115, 101, 116,  95, 109, 111, 109, 101, 110, 116, 117, 109,  32, 
   61,  32, 111, 102, 102, 115, 101, 116,  95, 109, 111, 109, 101, 110, 116, 117, 
  109,  44,  10,  32,  32,  32,  32,  97, 100, 118,  97, 110,  99, 101,  32,  61, 
   32,  97, 100, 118,  97, 110,  99, 101,  44,  10,  32,  32,  32,  32,  97, 100, 
  118,  97, 110,  99, 101,  95, 109, 117, 108, 116, 105, 112, 108, 101,  95, 115, 
  116, 101, 112, 115,  32,  61,  32,  97, 100, 118,  97, 110,  99, 101,  95, 109, 
  117, 108, 116, 105, 112, 108, 101,  95, 115, 116, 101, 112, 115,  44,  10,  32, 
   32,  32,  32, 101, 110, 101, 114, 103, 121,  32,  61,  32, 101, 110, 101, 114, 
  103, 121,  44,  10, 125,  10,   0
};
 
#define LUA_AOT_LUAOPEN_NAME luaopen_benchmarks_nbody_luaot
 
#include "luaot_footer.c"
