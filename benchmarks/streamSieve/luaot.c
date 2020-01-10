#include "luaot_header.c"
 
// source = @benchmarks/streamSieve/lua.lua
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
  
  // 2	[8]	CLOSURE  	0 0	; 0x1a25000
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
  
  // 3	[12]	CLOSURE  	1 1	; 0x1a25520
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
  
  // 4	[16]	CLOSURE  	2 2	; 0x1a25650
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
  
  // 5	[23]	CLOSURE  	3 3	; 0x1a257a0
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
  
  // 6	[29]	LOADNIL  	4 1	; 2 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_07
  label_05 : {
    aot_vmfetch(0x00010206);
    int b = GETARG_B(i);
    do {
      setnilvalue(s2v(ra++));
    } while (b--);
  }
  
  // 7	[33]	CLOSURE  	6 4	; 0x1a26020
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_08
  label_06 : {
    aot_vmfetch(0x0002034d);
    Proto *p = cl->p->p[GETARG_Bx(i)];
    halfProtect(pushclosure(L, p, cl->upvals, base, ra));
    checkGC(L, ra + 1);
  }
  
  // 8	[31]	MOVE     	4 6
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_09
  label_07 : {
    aot_vmfetch(0x00060200);
    setobjs2s(L, ra, RB(i));
  }
  
  // 9	[37]	CLOSURE  	6 5	; 0x1a26130
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 9)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_10
  label_08 : {
    aot_vmfetch(0x0002834d);
    Proto *p = cl->p->p[GETARG_Bx(i)];
    halfProtect(pushclosure(L, p, cl->upvals, base, ra));
    checkGC(L, ra + 1);
  }
  
  // 10	[35]	MOVE     	5 6
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 10)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_11
  label_09 : {
    aot_vmfetch(0x00060280);
    setobjs2s(L, ra, RB(i));
  }
  
  // 11	[41]	LOADNIL  	6 1	; 2 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 11)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_12
  label_10 : {
    aot_vmfetch(0x00010306);
    int b = GETARG_B(i);
    do {
      setnilvalue(s2v(ra++));
    } while (b--);
  }
  
  // 12	[53]	CLOSURE  	8 6	; 0x1a262e0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 12)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_13
  label_11 : {
    aot_vmfetch(0x0003044d);
    Proto *p = cl->p->p[GETARG_Bx(i)];
    halfProtect(pushclosure(L, p, cl->upvals, base, ra));
    checkGC(L, ra + 1);
  }
  
  // 13	[43]	MOVE     	6 8
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 13)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_14
  label_12 : {
    aot_vmfetch(0x00080300);
    setobjs2s(L, ra, RB(i));
  }
  
  // 14	[57]	CLOSURE  	8 7	; 0x1a26560
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 14)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_15
  label_13 : {
    aot_vmfetch(0x0003844d);
    Proto *p = cl->p->p[GETARG_Bx(i)];
    halfProtect(pushclosure(L, p, cl->upvals, base, ra));
    checkGC(L, ra + 1);
  }
  
  // 15	[55]	MOVE     	7 8
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 15)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_16
  label_14 : {
    aot_vmfetch(0x00080380);
    setobjs2s(L, ra, RB(i));
  }
  
  // 16	[61]	LOADNIL  	8 1	; 2 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 16)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_17
  label_15 : {
    aot_vmfetch(0x00010406);
    int b = GETARG_B(i);
    do {
      setnilvalue(s2v(ra++));
    } while (b--);
  }
  
  // 17	[68]	CLOSURE  	10 8	; 0x1a25f40
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 17)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_18
  label_16 : {
    aot_vmfetch(0x0004054d);
    Proto *p = cl->p->p[GETARG_Bx(i)];
    halfProtect(pushclosure(L, p, cl->upvals, base, ra));
    checkGC(L, ra + 1);
  }
  
  // 18	[63]	MOVE     	8 10
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 18)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_19
  label_17 : {
    aot_vmfetch(0x000a0400);
    setobjs2s(L, ra, RB(i));
  }
  
  // 19	[72]	CLOSURE  	10 9	; 0x1a269e0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 19)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_20
  label_18 : {
    aot_vmfetch(0x0004854d);
    Proto *p = cl->p->p[GETARG_Bx(i)];
    halfProtect(pushclosure(L, p, cl->upvals, base, ra));
    checkGC(L, ra + 1);
  }
  
  // 20	[70]	MOVE     	9 10
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 20)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_21
  label_19 : {
    aot_vmfetch(0x000a0480);
    setobjs2s(L, ra, RB(i));
  }
  
  // 21	[79]	CLOSURE  	10 10	; 0x1a26af0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 21)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_22
  label_20 : {
    aot_vmfetch(0x0005054d);
    Proto *p = cl->p->p[GETARG_Bx(i)];
    halfProtect(pushclosure(L, p, cl->upvals, base, ra));
    checkGC(L, ra + 1);
  }
  
  // 22	[81]	NEWTABLE 	11 1 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 22)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_23
  label_21 : {
    aot_vmfetch(0x00010591);
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
  
  // 23	[81]	EXTRAARG 	0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 23)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_24
  label_22 : {
    aot_vmfetch(0x00000050);
    lua_assert(0);
  }
  
  // 24	[82]	SETFIELD 	11 0 10	; "get_prime"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 24)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_25
  label_23 : {
    aot_vmfetch(0x0a000590);
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
  
  // 25	[83]	RETURN   	11 2 1	; 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 25)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_24 : {
    aot_vmfetch(0x010285c4);
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
  
  // 26	[83]	RETURN   	11 1 1	; 0 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 26)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_25 : {
    aot_vmfetch(0x010185c4);
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
 
// source = @benchmarks/streamSieve/lua.lua
// lines: 6 - 8
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
 
  // 1	[7]	NEWTABLE 	3 0 3
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 1)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_02
  label_00 : {
    aot_vmfetch(0x03000191);
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
  
  // 2	[7]	EXTRAARG 	0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x00000050);
    lua_assert(0);
  }
  
  // 3	[7]	MOVE     	4 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x00000200);
    setobjs2s(L, ra, RB(i));
  }
  
  // 4	[7]	MOVE     	5 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0x00010280);
    setobjs2s(L, ra, RB(i));
  }
  
  // 5	[7]	MOVE     	6 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x00020300);
    setobjs2s(L, ra, RB(i));
  }
  
  // 6	[7]	SETLIST  	3 3 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_07
  label_05 : {
    aot_vmfetch(0x000301cc);
        int n = GETARG_B(i);
        unsigned int last = GETARG_C(i);
        Table *h = hvalue(s2v(ra));
        if (n == 0)
          n = cast_int(L->top - ra) - 1;  /* get up to the top */
        else
          L->top = ci->top;  /* correct top in case of emergency GC */
        last += n;
        int has_extra_arg = TESTARG_k(i);
        if (has_extra_arg) {
          last += GETARG_Ax(0x000201c6) * (MAXARG_C + 1);
        }
        if (last > luaH_realasize(h))  /* needs more space? */
          luaH_resizearray(L, h, last);  /* preallocate it at once */
        for (; n > 0; n--) {
          TValue *val = s2v(ra + n);
          setobj2t(L, &h->array[last - 1], val);
          last--;
          luaC_barrierback(L, obj2gco(h), val);
        }
        if (has_extra_arg) {
          goto LUA_AOT_SKIP1;
        }
  }
  
  // 7	[7]	RETURN1  	3
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_06 : {
    aot_vmfetch(0x000201c6);
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
  
  // 8	[8]	RETURN0  	
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_07 : {
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
 
// source = @benchmarks/streamSieve/lua.lua
// lines: 10 - 12
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
 
  // 1	[11]	GETI     	1 0 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 1)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_02
  label_00 : {
    aot_vmfetch(0x0100008b);
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
  
  // 2	[11]	RETURN1  	1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_01 : {
    aot_vmfetch(0x000200c6);
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
  
  // 3	[12]	RETURN0  	
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_02 : {
    aot_vmfetch(0x000100c5);
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
 
// source = @benchmarks/streamSieve/lua.lua
// lines: 14 - 16
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
 
  // 1	[15]	GETI     	1 0 3
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 1)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_02
  label_00 : {
    aot_vmfetch(0x0300008b);
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
  
  // 2	[15]	GETI     	2 0 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x0200010b);
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
  
  // 3	[15]	CALL     	1 2 2	; 1 in 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x020200c2);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 4	[15]	RETURN1  	1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_03 : {
    aot_vmfetch(0x000200c6);
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
  
  // 5	[16]	RETURN0  	
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_04 : {
    aot_vmfetch(0x000100c5);
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
 
// source = @benchmarks/streamSieve/lua.lua
// lines: 18 - 23
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
 
  // 1	[19]	LOADI    	2 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 1)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_02
  label_00 : {
    aot_vmfetch(0x80000101);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }
  
  // 2	[19]	ADDI     	3 1 -1 
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x7e010193);
    op_arithI(L, l_addi, luai_numadd, TM_ADD, GETARG_k(i));
  }
  
  // 3	[19]	MMBINI   	1 1 7	; __sub
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x078000ad);
    Instruction pi = 0x7e010193;  /* original arith. expression */
    int imm = GETARG_sB(i);
    TMS tm = (TMS)GETARG_C(i);
    int flip = GETARG_k(i);
    StkId result = RA(pi);
    Protect(luaT_trybiniTM(L, s2v(ra), imm, flip, result, tm));
  }
  
  // 4	[19]	LOADI    	4 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0x80000201);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }
  
  // 5	[19]	FORPREP  	2 4	; to 10
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x00020148);
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
        goto label_10; /* skip the loop */
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
        goto label_10; /* skip the loop */
      else {
        /* make sure internal values are all float */
        setfltvalue(plimit, limit);
        setfltvalue(pstep, step);
        setfltvalue(s2v(ra), init);  /* internal index */
        setfltvalue(s2v(ra + 3), init);  /* control variable */
      }
    }
  }
  
  // 6	[20]	GETUPVAL 	6 0	; stream_tail
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_07
  label_05 : {
    aot_vmfetch(0x00000307);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }
  
  // 7	[20]	MOVE     	7 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_08
  label_06 : {
    aot_vmfetch(0x00000380);
    setobjs2s(L, ra, RB(i));
  }
  
  // 8	[20]	CALL     	6 2 2	; 1 in 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_09
  label_07 : {
    aot_vmfetch(0x02020342);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 9	[20]	MOVE     	0 6
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 9)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_10
  label_08 : {
    aot_vmfetch(0x00060000);
    setobjs2s(L, ra, RB(i));
  }
  
  // 10	[19]	FORLOOP  	2 5	; to 6
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 10)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_11
  label_09 : {
    aot_vmfetch(0x00028147);
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
  
  // 11	[22]	GETUPVAL 	2 1	; stream_head
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 11)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_12
  label_10 : {
    aot_vmfetch(0x00010107);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }
  
  // 12	[22]	MOVE     	3 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 12)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_13
  label_11 : {
    aot_vmfetch(0x00000180);
    setobjs2s(L, ra, RB(i));
  }
  
  // 13	[22]	CALL     	2 2 2	; 1 in 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 13)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_14
  label_12 : {
    aot_vmfetch(0x02020142);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 14	[22]	RETURN1  	2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 14)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_13 : {
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
  
  // 15	[23]	RETURN0  	
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 15)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_14 : {
    aot_vmfetch(0x00010145);
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
 
// source = @benchmarks/streamSieve/lua.lua
// lines: 31 - 33
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
 
  // 1	[32]	GETUPVAL 	1 0	; make_stream
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 1)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_02
  label_00 : {
    aot_vmfetch(0x00000087);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }
  
  // 2	[32]	MOVE     	2 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x00000100);
    setobjs2s(L, ra, RB(i));
  }
  
  // 3	[32]	MOVE     	3 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x00000180);
    setobjs2s(L, ra, RB(i));
  }
  
  // 4	[32]	GETUPVAL 	4 1	; _tail1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0x00010207);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }
  
  // 5	[32]	CALL     	1 4 2	; 3 in 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x020400c2);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 6	[32]	RETURN1  	1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_05 : {
    aot_vmfetch(0x000200c6);
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
  
  // 7	[33]	RETURN0  	
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_06 : {
    aot_vmfetch(0x000100c5);
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
 
// source = @benchmarks/streamSieve/lua.lua
// lines: 35 - 37
static
void magic_implementation_06(lua_State *L, CallInfo *ci)
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
 
  // 1	[36]	GETUPVAL 	1 0	; count_from
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 1)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_02
  label_00 : {
    aot_vmfetch(0x00000087);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }
  
  // 2	[36]	ADDI     	2 0 1 
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x80000113);
    op_arithI(L, l_addi, luai_numadd, TM_ADD, GETARG_k(i));
  }
  
  // 3	[36]	MMBINI   	0 1 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x0680002d);
    Instruction pi = 0x80000113;  /* original arith. expression */
    int imm = GETARG_sB(i);
    TMS tm = (TMS)GETARG_C(i);
    int flip = GETARG_k(i);
    StkId result = RA(pi);
    Protect(luaT_trybiniTM(L, s2v(ra), imm, flip, result, tm));
  }
  
  // 4	[36]	CALL     	1 2 2	; 1 in 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0x020200c2);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 5	[36]	RETURN1  	1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_04 : {
    aot_vmfetch(0x000200c6);
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
  
  // 6	[37]	RETURN0  	
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_05 : {
    aot_vmfetch(0x000100c5);
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
 
// source = @benchmarks/streamSieve/lua.lua
// lines: 43 - 53
static
void magic_implementation_07(lua_State *L, CallInfo *ci)
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
 
  // 1	[44]	GETUPVAL 	2 0	; stream_head
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 1)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_02
  label_00 : {
    aot_vmfetch(0x00000107);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }
  
  // 2	[44]	MOVE     	3 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x00010180);
    setobjs2s(L, ra, RB(i));
  }
  
  // 3	[44]	CALL     	2 2 2	; 1 in 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x02020142);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 4	[45]	GETUPVAL 	3 1	; stream_tail
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0x00010187);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }
  
  // 5	[45]	MOVE     	4 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x00010200);
    setobjs2s(L, ra, RB(i));
  }
  
  // 6	[45]	CALL     	3 2 2	; 1 in 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_07
  label_05 : {
    aot_vmfetch(0x020201c2);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 7	[46]	MOD      	4 2 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_08
  label_06 : {
    aot_vmfetch(0x00020223);
    op_arith(L, luaV_mod, luaV_modf);
  }
  
  // 8	[46]	MMBIN    	2 0 9	; __mod
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_09
  label_07 : {
    aot_vmfetch(0x0900012c);
    Instruction pi = 0x00020223; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 9	[46]	EQI      	4 0 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 9)
  #undef  LUA_AOT_NEXT_JUMP
  #define LUA_AOT_NEXT_JUMP label_20
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_10
  label_08 : {
    aot_vmfetch(0x007f023b);
    int cond;
    int im = GETARG_sB(i);
    if (ttisinteger(s2v(ra)))
      cond = (ivalue(s2v(ra)) == im);
    else if (ttisfloat(s2v(ra)))
      cond = luai_numeq(fltvalue(s2v(ra)), cast_num(im));
    else
      cond = 0;  /* other types cannot be equal to a number */
    docondjump();
  }
  
  // 10	[46]	JMP      	10	; to 21
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 10)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_11
  label_09 : {
    aot_vmfetch(0x800004b6);
    updatetrap(ci);
    goto label_20;
  }
  
  // 11	[47]	MOVE     	1 3
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 11)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_12
  label_10 : {
    aot_vmfetch(0x00030080);
    setobjs2s(L, ra, RB(i));
  }
  
  // 12	[48]	GETUPVAL 	4 0	; stream_head
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 12)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_13
  label_11 : {
    aot_vmfetch(0x00000207);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }
  
  // 13	[48]	MOVE     	5 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 13)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_14
  label_12 : {
    aot_vmfetch(0x00010280);
    setobjs2s(L, ra, RB(i));
  }
  
  // 14	[48]	CALL     	4 2 2	; 1 in 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 14)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_15
  label_13 : {
    aot_vmfetch(0x02020242);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 15	[48]	MOVE     	2 4
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 15)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_16
  label_14 : {
    aot_vmfetch(0x00040100);
    setobjs2s(L, ra, RB(i));
  }
  
  // 16	[49]	GETUPVAL 	4 1	; stream_tail
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 16)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_17
  label_15 : {
    aot_vmfetch(0x00010207);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }
  
  // 17	[49]	MOVE     	5 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 17)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_18
  label_16 : {
    aot_vmfetch(0x00010280);
    setobjs2s(L, ra, RB(i));
  }
  
  // 18	[49]	CALL     	4 2 2	; 1 in 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 18)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_19
  label_17 : {
    aot_vmfetch(0x02020242);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 19	[49]	MOVE     	3 4
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 19)
  #undef  LUA_AOT_NEXT_JUMP
  #define LUA_AOT_NEXT_JUMP label_06
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_20
  label_18 : {
    aot_vmfetch(0x00040180);
    setobjs2s(L, ra, RB(i));
  }
  
  // 20	[49]	JMP      	-14	; to 7
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 20)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_21
  label_19 : {
    aot_vmfetch(0x7ffff8b6);
    updatetrap(ci);
    goto label_06;
  }
  
  // 21	[51]	NEWTABLE 	4 0 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 21)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_22
  label_20 : {
    aot_vmfetch(0x02000211);
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
  
  // 22	[51]	EXTRAARG 	0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 22)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_23
  label_21 : {
    aot_vmfetch(0x00000050);
    lua_assert(0);
  }
  
  // 23	[51]	MOVE     	5 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 23)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_24
  label_22 : {
    aot_vmfetch(0x00000280);
    setobjs2s(L, ra, RB(i));
  }
  
  // 24	[51]	MOVE     	6 3
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 24)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_25
  label_23 : {
    aot_vmfetch(0x00030300);
    setobjs2s(L, ra, RB(i));
  }
  
  // 25	[51]	SETLIST  	4 2 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 25)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_26
  label_24 : {
    aot_vmfetch(0x0002024c);
        int n = GETARG_B(i);
        unsigned int last = GETARG_C(i);
        Table *h = hvalue(s2v(ra));
        if (n == 0)
          n = cast_int(L->top - ra) - 1;  /* get up to the top */
        else
          L->top = ci->top;  /* correct top in case of emergency GC */
        last += n;
        int has_extra_arg = TESTARG_k(i);
        if (has_extra_arg) {
          last += GETARG_Ax(0x00020287) * (MAXARG_C + 1);
        }
        if (last > luaH_realasize(h))  /* needs more space? */
          luaH_resizearray(L, h, last);  /* preallocate it at once */
        for (; n > 0; n--) {
          TValue *val = s2v(ra + n);
          setobj2t(L, &h->array[last - 1], val);
          last--;
          luaC_barrierback(L, obj2gco(h), val);
        }
        if (has_extra_arg) {
          goto LUA_AOT_SKIP1;
        }
  }
  
  // 26	[52]	GETUPVAL 	5 2	; make_stream
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 26)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_27
  label_25 : {
    aot_vmfetch(0x00020287);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }
  
  // 27	[52]	MOVE     	6 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 27)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_28
  label_26 : {
    aot_vmfetch(0x00020300);
    setobjs2s(L, ra, RB(i));
  }
  
  // 28	[52]	MOVE     	7 4
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 28)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_29
  label_27 : {
    aot_vmfetch(0x00040380);
    setobjs2s(L, ra, RB(i));
  }
  
  // 29	[52]	GETUPVAL 	8 3	; _tail2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 29)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_30
  label_28 : {
    aot_vmfetch(0x00030407);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }
  
  // 30	[52]	CALL     	5 4 2	; 3 in 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 30)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_31
  label_29 : {
    aot_vmfetch(0x020402c2);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 31	[52]	RETURN1  	5
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 31)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_30 : {
    aot_vmfetch(0x000202c6);
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
  
  // 32	[53]	RETURN0  	
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 32)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_31 : {
    aot_vmfetch(0x000102c5);
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
 
// source = @benchmarks/streamSieve/lua.lua
// lines: 55 - 57
static
void magic_implementation_08(lua_State *L, CallInfo *ci)
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
 
  // 1	[56]	GETUPVAL 	1 0	; sift
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 1)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_02
  label_00 : {
    aot_vmfetch(0x00000087);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }
  
  // 2	[56]	GETI     	2 0 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x0100010b);
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
  
  // 3	[56]	GETI     	3 0 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x0200018b);
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
  
  // 4	[56]	CALL     	1 3 2	; 2 in 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0x020300c2);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 5	[56]	RETURN1  	1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_04 : {
    aot_vmfetch(0x000200c6);
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
  
  // 6	[57]	RETURN0  	
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_05 : {
    aot_vmfetch(0x000100c5);
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
 
// source = @benchmarks/streamSieve/lua.lua
// lines: 63 - 68
static
void magic_implementation_09(lua_State *L, CallInfo *ci)
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
 
  // 1	[64]	GETUPVAL 	1 0	; stream_head
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 1)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_02
  label_00 : {
    aot_vmfetch(0x00000087);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }
  
  // 2	[64]	MOVE     	2 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x00000100);
    setobjs2s(L, ra, RB(i));
  }
  
  // 3	[64]	CALL     	1 2 2	; 1 in 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x020200c2);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 4	[65]	GETUPVAL 	2 1	; stream_tail
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0x00010107);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }
  
  // 5	[65]	MOVE     	3 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x00000180);
    setobjs2s(L, ra, RB(i));
  }
  
  // 6	[65]	CALL     	2 2 2	; 1 in 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_07
  label_05 : {
    aot_vmfetch(0x02020142);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 7	[66]	NEWTABLE 	3 0 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_08
  label_06 : {
    aot_vmfetch(0x02000191);
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
  
  // 8	[66]	EXTRAARG 	0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_09
  label_07 : {
    aot_vmfetch(0x00000050);
    lua_assert(0);
  }
  
  // 9	[66]	MOVE     	4 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 9)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_10
  label_08 : {
    aot_vmfetch(0x00010200);
    setobjs2s(L, ra, RB(i));
  }
  
  // 10	[66]	MOVE     	5 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 10)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_11
  label_09 : {
    aot_vmfetch(0x00020280);
    setobjs2s(L, ra, RB(i));
  }
  
  // 11	[66]	SETLIST  	3 2 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 11)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_12
  label_10 : {
    aot_vmfetch(0x000201cc);
        int n = GETARG_B(i);
        unsigned int last = GETARG_C(i);
        Table *h = hvalue(s2v(ra));
        if (n == 0)
          n = cast_int(L->top - ra) - 1;  /* get up to the top */
        else
          L->top = ci->top;  /* correct top in case of emergency GC */
        last += n;
        int has_extra_arg = TESTARG_k(i);
        if (has_extra_arg) {
          last += GETARG_Ax(0x00020207) * (MAXARG_C + 1);
        }
        if (last > luaH_realasize(h))  /* needs more space? */
          luaH_resizearray(L, h, last);  /* preallocate it at once */
        for (; n > 0; n--) {
          TValue *val = s2v(ra + n);
          setobj2t(L, &h->array[last - 1], val);
          last--;
          luaC_barrierback(L, obj2gco(h), val);
        }
        if (has_extra_arg) {
          goto LUA_AOT_SKIP1;
        }
  }
  
  // 12	[67]	GETUPVAL 	4 2	; make_stream
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 12)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_13
  label_11 : {
    aot_vmfetch(0x00020207);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }
  
  // 13	[67]	MOVE     	5 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 13)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_14
  label_12 : {
    aot_vmfetch(0x00010280);
    setobjs2s(L, ra, RB(i));
  }
  
  // 14	[67]	MOVE     	6 3
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 14)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_15
  label_13 : {
    aot_vmfetch(0x00030300);
    setobjs2s(L, ra, RB(i));
  }
  
  // 15	[67]	GETUPVAL 	7 3	; _tail3
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 15)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_16
  label_14 : {
    aot_vmfetch(0x00030387);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }
  
  // 16	[67]	CALL     	4 4 2	; 3 in 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 16)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_17
  label_15 : {
    aot_vmfetch(0x02040242);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 17	[67]	RETURN1  	4
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 17)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_16 : {
    aot_vmfetch(0x00020246);
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
  
  // 18	[68]	RETURN0  	
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 18)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_17 : {
    aot_vmfetch(0x00010245);
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
 
// source = @benchmarks/streamSieve/lua.lua
// lines: 70 - 72
static
void magic_implementation_10(lua_State *L, CallInfo *ci)
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
 
  // 1	[71]	GETUPVAL 	1 0	; sieve
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 1)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_02
  label_00 : {
    aot_vmfetch(0x00000087);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }
  
  // 2	[71]	GETUPVAL 	2 1	; sift
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x00010107);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }
  
  // 3	[71]	GETI     	3 0 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x0100018b);
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
  
  // 4	[71]	GETI     	4 0 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0x0200020b);
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
  
  // 5	[71]	CALL     	2 3 0	; 2 in all out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x00030142);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 6	[71]	CALL     	1 0 2	; all in 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_07
  label_05 : {
    aot_vmfetch(0x020000c2);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 7	[71]	RETURN1  	1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_06 : {
    aot_vmfetch(0x000200c6);
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
  
  // 8	[72]	RETURN0  	
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_07 : {
    aot_vmfetch(0x000100c5);
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
 
// source = @benchmarks/streamSieve/lua.lua
// lines: 76 - 79
static
void magic_implementation_11(lua_State *L, CallInfo *ci)
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
 
  // 1	[77]	GETUPVAL 	1 0	; sieve
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 1)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_02
  label_00 : {
    aot_vmfetch(0x00000087);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }
  
  // 2	[77]	GETUPVAL 	2 1	; count_from
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x00010107);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }
  
  // 3	[77]	LOADI    	3 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x80008181);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }
  
  // 4	[77]	CALL     	2 2 0	; 1 in all out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0x00020142);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 5	[77]	CALL     	1 0 2	; all in 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x020000c2);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 6	[78]	GETUPVAL 	2 2	; stream_get
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_07
  label_05 : {
    aot_vmfetch(0x00020107);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }
  
  // 7	[78]	MOVE     	3 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_08
  label_06 : {
    aot_vmfetch(0x00010180);
    setobjs2s(L, ra, RB(i));
  }
  
  // 8	[78]	MOVE     	4 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_09
  label_07 : {
    aot_vmfetch(0x00000200);
    setobjs2s(L, ra, RB(i));
  }
  
  // 9	[78]	CALL     	2 3 2	; 2 in 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 9)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_10
  label_08 : {
    aot_vmfetch(0x02030142);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 10	[78]	RETURN1  	2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 10)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_09 : {
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
  
  // 11	[79]	RETURN0  	
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 11)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_10 : {
    aot_vmfetch(0x00010145);
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
  magic_implementation_06,
  magic_implementation_07,
  magic_implementation_08,
  magic_implementation_09,
  magic_implementation_10,
  magic_implementation_11,
  NULL
};
 
static const char LUA_AOT_MODULE_SOURCE_CODE[] = {
   10,  45,  45,  32,  83, 105, 109, 112, 108, 101,  32, 115, 116, 114, 101,  97, 
  109, 115,  32, 108, 105,  98, 114,  97, 114, 121,  32, 102, 111, 114,  32,  98, 
  117, 105, 108, 100, 105, 110, 103,  32, 105, 110, 102, 105, 110, 105, 116, 101, 
   32, 108, 105, 115, 116, 115,  46,  10,  45,  45,  32,  66,  97, 115, 101, 100, 
   32, 111, 110,  32, 116, 104, 101,  32, 105, 109, 112, 108, 101, 109, 101, 110, 
  116,  97, 116, 105, 111, 110,  32, 102, 114, 111, 109,  32,  82,  97,  99, 107, 
  101, 116,  44,  32,  98, 117, 116,  32, 109, 111, 100, 105, 102, 105, 101, 100, 
   32, 116, 111,  32, 117, 115, 101,  32, 101, 120, 112, 108, 105,  99, 105, 116, 
   10,  45,  45,  32, 112,  97, 114,  97, 109, 101, 116, 101, 114, 115,  32, 105, 
  110, 115, 116, 101,  97, 100,  32, 111, 102,  32,  99, 108, 111, 115, 117, 114, 
  101, 115,  10,  10, 108, 111,  99,  97, 108,  32, 102, 117, 110,  99, 116, 105, 
  111, 110,  32, 109,  97, 107, 101,  95, 115, 116, 114, 101,  97, 109,  40, 104, 
  101,  97, 100,  44,  32, 115, 116,  97, 116, 101,  44,  32, 103, 101, 116,  95, 
  116,  97, 105, 108,  41,  10,  32,  32,  32,  32, 114, 101, 116, 117, 114, 110, 
   32, 123,  32, 104, 101,  97, 100,  44,  32, 115, 116,  97, 116, 101,  44,  32, 
  103, 101, 116,  95, 116,  97, 105, 108,  32, 125,  10, 101, 110, 100,  10,  10, 
  108, 111,  99,  97, 108,  32, 102, 117, 110,  99, 116, 105, 111, 110,  32, 115, 
  116, 114, 101,  97, 109,  95, 104, 101,  97, 100,  40, 115, 116,  41,  10,  32, 
   32,  32,  32, 114, 101, 116, 117, 114, 110,  32, 115, 116,  91,  49,  93,  10, 
  101, 110, 100,  10,  10, 108, 111,  99,  97, 108,  32, 102, 117, 110,  99, 116, 
  105, 111, 110,  32, 115, 116, 114, 101,  97, 109,  95, 116,  97, 105, 108,  40, 
  115, 116,  41,  10,  32,  32,  32,  32, 114, 101, 116, 117, 114, 110,  32,  40, 
  115, 116,  91,  51,  93,  40, 115, 116,  91,  50,  93,  41,  41,  10, 101, 110, 
  100,  10,  10, 108, 111,  99,  97, 108,  32, 102, 117, 110,  99, 116, 105, 111, 
  110,  32, 115, 116, 114, 101,  97, 109,  95, 103, 101, 116,  40, 115, 116,  44, 
   32, 110,  41,  10,  32,  32,  32,  32, 102, 111, 114,  32,  95,  32,  61,  32, 
   49,  44,  32, 110,  45,  49,  32, 100, 111,  10,  32,  32,  32,  32,  32,  32, 
   32,  32, 115, 116,  32,  61,  32, 115, 116, 114, 101,  97, 109,  95, 116,  97, 
  105, 108,  40, 115, 116,  41,  10,  32,  32,  32,  32, 101, 110, 100,  10,  32, 
   32,  32,  32, 114, 101, 116, 117, 114, 110,  32,  40, 115, 116, 114, 101,  97, 
  109,  95, 104, 101,  97, 100,  40, 115, 116,  41,  41,  10, 101, 110, 100,  10, 
   10,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45, 
   45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45, 
   45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  10, 
   10,  45,  45,  32,  66, 117, 105, 108, 100,  32,  97,  32, 115, 116, 114, 101, 
   97, 109,  32, 111, 102,  32, 105, 110, 116, 101, 103, 101, 114, 115,  32, 115, 
  116,  97, 114, 116, 105, 110, 103,  32, 102, 114, 111, 109,  32,  49,  10,  10, 
  108, 111,  99,  97, 108,  32,  99, 111, 117, 110, 116,  95, 102, 114, 111, 109, 
   44,  32,  95, 116,  97, 105, 108,  49,  10,  10, 102, 117, 110,  99, 116, 105, 
  111, 110,  32,  99, 111, 117, 110, 116,  95, 102, 114, 111, 109,  40, 110,  41, 
   10,  32,  32,  32,  32, 114, 101, 116, 117, 114, 110,  32,  40, 109,  97, 107, 
  101,  95, 115, 116, 114, 101,  97, 109,  40, 110,  44,  32, 110,  44,  32,  95, 
  116,  97, 105, 108,  49,  41,  41,  10, 101, 110, 100,  10,  10, 102, 117, 110, 
   99, 116, 105, 111, 110,  32,  95, 116,  97, 105, 108,  49,  40, 105,  41,  10, 
   32,  32,  32,  32, 114, 101, 116, 117, 114, 110,  32,  40,  99, 111, 117, 110, 
  116,  95, 102, 114, 111, 109,  40, 105,  43,  49,  41,  41,  10, 101, 110, 100, 
   10,  10,  45,  45,  32,  70, 105, 108, 116, 101, 114,  32,  97, 108, 108,  32, 
  109, 117, 108, 116, 105, 112, 108, 101, 115,  32, 111, 102,  32, 110,  10,  10, 
  108, 111,  99,  97, 108,  32, 115, 105, 102, 116,  44,  32,  95, 116,  97, 105, 
  108,  50,  10,  10, 102, 117, 110,  99, 116, 105, 111, 110,  32, 115, 105, 102, 
  116,  40, 110,  44,  32, 115, 116,  41,  10,  32,  32,  32,  32, 108, 111,  99, 
   97, 108,  32, 104, 100,  32,  61,  32, 115, 116, 114, 101,  97, 109,  95, 104, 
  101,  97, 100,  40, 115, 116,  41,  10,  32,  32,  32,  32, 108, 111,  99,  97, 
  108,  32, 116, 108,  32,  61,  32, 115, 116, 114, 101,  97, 109,  95, 116,  97, 
  105, 108,  40, 115, 116,  41,  10,  32,  32,  32,  32, 119, 104, 105, 108, 101, 
   32, 104, 100,  32,  37,  32, 110,  32,  61,  61,  32,  48,  32, 100, 111,  10, 
   32,  32,  32,  32,  32,  32,  32,  32, 115, 116,  32,  61,  32, 116, 108,  10, 
   32,  32,  32,  32,  32,  32,  32,  32, 104, 100,  32,  61,  32, 115, 116, 114, 
  101,  97, 109,  95, 104, 101,  97, 100,  40, 115, 116,  41,  10,  32,  32,  32, 
   32,  32,  32,  32,  32, 116, 108,  32,  61,  32, 115, 116, 114, 101,  97, 109, 
   95, 116,  97, 105, 108,  40, 115, 116,  41,  10,  32,  32,  32,  32, 101, 110, 
  100,  10,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32, 115, 116,  97, 116, 
  101,  32,  61,  32, 123,  32, 110,  44,  32, 116, 108,  32, 125,  10,  32,  32, 
   32,  32, 114, 101, 116, 117, 114, 110,  32,  40, 109,  97, 107, 101,  95, 115, 
  116, 114, 101,  97, 109,  40, 104, 100,  44,  32, 115, 116,  97, 116, 101,  44, 
   32,  95, 116,  97, 105, 108,  50,  41,  41,  10, 101, 110, 100,  10,  10, 102, 
  117, 110,  99, 116, 105, 111, 110,  32,  95, 116,  97, 105, 108,  50,  40, 115, 
  116,  97, 116, 101,  41,  10,  32,  32,  32,  32, 114, 101, 116, 117, 114, 110, 
   32,  40, 115, 105, 102, 116,  40, 115, 116,  97, 116, 101,  91,  49,  93,  44, 
   32, 115, 116,  97, 116, 101,  91,  50,  93,  41,  41,  10, 101, 110, 100,  10, 
   10,  45,  45,  32,  78,  97, 105, 118, 101,  32, 115, 105, 101, 118, 101,  32, 
  111, 102,  32,  69, 114,  97, 115, 116, 104, 111, 115, 116, 101, 110, 101, 115, 
   10,  10, 108, 111,  99,  97, 108,  32, 115, 105, 101, 118, 101,  44,  32,  95, 
  116,  97, 105, 108,  51,  10,  10, 102, 117, 110,  99, 116, 105, 111, 110,  32, 
  115, 105, 101, 118, 101,  40, 115, 116,  41,  10,  32,  32,  32,  32, 108, 111, 
   99,  97, 108,  32, 110,  32,  32,  61,  32, 115, 116, 114, 101,  97, 109,  95, 
  104, 101,  97, 100,  40, 115, 116,  41,  10,  32,  32,  32,  32, 108, 111,  99, 
   97, 108,  32, 116, 108,  32,  61,  32, 115, 116, 114, 101,  97, 109,  95, 116, 
   97, 105, 108,  40, 115, 116,  41,  10,  32,  32,  32,  32, 108, 111,  99,  97, 
  108,  32, 115, 116,  97, 116, 101,  32,  61,  32, 123,  32, 110,  44,  32, 116, 
  108,  32, 125,  10,  32,  32,  32,  32, 114, 101, 116, 117, 114, 110,  32,  40, 
  109,  97, 107, 101,  95, 115, 116, 114, 101,  97, 109,  40, 110,  44,  32, 115, 
  116,  97, 116, 101,  44,  32,  95, 116,  97, 105, 108,  51,  41,  41,  10, 101, 
  110, 100,  10,  10, 102, 117, 110,  99, 116, 105, 111, 110,  32,  95, 116,  97, 
  105, 108,  51,  40, 115, 116,  97, 116, 101,  41,  10,  32,  32,  32,  32, 114, 
  101, 116, 117, 114, 110,  32,  40, 115, 105, 101, 118, 101,  40, 115, 105, 102, 
  116,  40, 115, 116,  97, 116, 101,  91,  49,  93,  44,  32, 115, 116,  97, 116, 
  101,  91,  50,  93,  41,  41,  41,  10, 101, 110, 100,  10,  10,  45,  45,  10, 
   10, 108, 111,  99,  97, 108,  32, 102, 117, 110,  99, 116, 105, 111, 110,  32, 
  103, 101, 116,  95, 112, 114, 105, 109, 101,  40, 110,  41,  10,  32,  32,  32, 
   32, 108, 111,  99,  97, 108,  32, 112, 114, 105, 109, 101,  95, 115, 116, 114, 
  101,  97, 109,  32,  61,  32, 115, 105, 101, 118, 101,  40,  99, 111, 117, 110, 
  116,  95, 102, 114, 111, 109,  40,  50,  41,  41,  10,  32,  32,  32,  32, 114, 
  101, 116, 117, 114, 110,  32,  40, 115, 116, 114, 101,  97, 109,  95, 103, 101, 
  116,  40, 112, 114, 105, 109, 101,  95, 115, 116, 114, 101,  97, 109,  44,  32, 
  110,  41,  41,  10, 101, 110, 100,  10,  10, 114, 101, 116, 117, 114, 110,  32, 
  123,  10,  32,  32,  32,  32, 103, 101, 116,  95, 112, 114, 105, 109, 101,  32, 
   61,  32, 103, 101, 116,  95, 112, 114, 105, 109, 101,  10, 125,  10,   0
};
 
#define LUA_AOT_LUAOPEN_NAME luaopen_benchmarks_streamSieve_luaot
 
#include "luaot_footer.c"
