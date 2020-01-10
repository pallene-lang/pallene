#include "luaot_header.c"
 
// source = @benchmarks/binarytrees/lua.lua
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
  
  // 2	[10]	CLOSURE  	0 0	; 0x1725000
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
  
  // 3	[18]	CLOSURE  	1 1	; 0x1725600
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
  
  // 4	[28]	CLOSURE  	2 2	; 0x17257f0
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
  
  // 5	[30]	NEWTABLE 	3 3 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x00030191);
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
  
  // 6	[30]	EXTRAARG 	0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_07
  label_05 : {
    aot_vmfetch(0x00000050);
    lua_assert(0);
  }
  
  // 7	[31]	SETFIELD 	3 0 0	; "BottomUpTree"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_08
  label_06 : {
    aot_vmfetch(0x00000190);
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
  
  // 8	[32]	SETFIELD 	3 1 1	; "ItemCheck"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_09
  label_07 : {
    aot_vmfetch(0x01010190);
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
  
  // 9	[33]	SETFIELD 	3 2 2	; "Stress"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 9)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_10
  label_08 : {
    aot_vmfetch(0x02020190);
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
  
  // 10	[34]	RETURN   	3 2 1	; 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 10)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_09 : {
    aot_vmfetch(0x010281c4);
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
  
  // 11	[34]	RETURN   	3 1 1	; 0 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 11)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_10 : {
    aot_vmfetch(0x010181c4);
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
 
// source = @benchmarks/binarytrees/lua.lua
// lines: 1 - 10
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
 
  // 1	[2]	GTI      	0 0 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 1)
  #undef  LUA_AOT_NEXT_JUMP
  #define LUA_AOT_NEXT_JUMP label_17
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_02
  label_00 : {
    aot_vmfetch(0x007f003e);
    op_orderI(L, l_gti, luai_numgt, 1, TM_LT);
  }
  
  // 2	[2]	JMP      	15	; to 18
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x80000736);
    updatetrap(ci);
    goto label_17;
  }
  
  // 3	[3]	ADDI     	0 0 -1 
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x7e000013);
    op_arithI(L, l_addi, luai_numadd, TM_ADD, GETARG_k(i));
  }
  
  // 4	[3]	MMBINI   	0 1 7	; __sub
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0x0780002d);
    Instruction pi = 0x7e000013;  /* original arith. expression */
    int imm = GETARG_sB(i);
    TMS tm = (TMS)GETARG_C(i);
    int flip = GETARG_k(i);
    StkId result = RA(pi);
    Protect(luaT_trybiniTM(L, s2v(ra), imm, flip, result, tm));
  }
  
  // 5	[4]	GETUPVAL 	1 0	; BottomUpTree
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x00000087);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }
  
  // 6	[4]	MOVE     	2 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_07
  label_05 : {
    aot_vmfetch(0x00000100);
    setobjs2s(L, ra, RB(i));
  }
  
  // 7	[4]	CALL     	1 2 2	; 1 in 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_08
  label_06 : {
    aot_vmfetch(0x020200c2);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 8	[5]	GETUPVAL 	2 0	; BottomUpTree
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_09
  label_07 : {
    aot_vmfetch(0x00000107);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }
  
  // 9	[5]	MOVE     	3 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 9)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_10
  label_08 : {
    aot_vmfetch(0x00000180);
    setobjs2s(L, ra, RB(i));
  }
  
  // 10	[5]	CALL     	2 2 2	; 1 in 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 10)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_11
  label_09 : {
    aot_vmfetch(0x02020142);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 11	[6]	NEWTABLE 	3 0 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 11)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_12
  label_10 : {
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
  
  // 12	[6]	EXTRAARG 	0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 12)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_13
  label_11 : {
    aot_vmfetch(0x00000050);
    lua_assert(0);
  }
  
  // 13	[6]	MOVE     	4 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 13)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_14
  label_12 : {
    aot_vmfetch(0x00010200);
    setobjs2s(L, ra, RB(i));
  }
  
  // 14	[6]	MOVE     	5 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 14)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_15
  label_13 : {
    aot_vmfetch(0x00020280);
    setobjs2s(L, ra, RB(i));
  }
  
  // 15	[6]	SETLIST  	3 2 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 15)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_16
  label_14 : {
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
  
  // 16	[6]	RETURN1  	3
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 16)
  #undef  LUA_AOT_NEXT_JUMP
  #define LUA_AOT_NEXT_JUMP label_23
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_17
  label_15 : {
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
  
  // 17	[6]	JMP      	6	; to 24
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 17)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_18
  label_16 : {
    aot_vmfetch(0x800002b6);
    updatetrap(ci);
    goto label_23;
  }
  
  // 18	[8]	NEWTABLE 	1 0 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 18)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_19
  label_17 : {
    aot_vmfetch(0x02000091);
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
  
  // 19	[8]	EXTRAARG 	0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 19)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_20
  label_18 : {
    aot_vmfetch(0x00000050);
    lua_assert(0);
  }
  
  // 20	[8]	LOADBOOL 	2 0 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 20)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_21
  label_19 : {
    aot_vmfetch(0x00000105);
    setbvalue(s2v(ra), GETARG_B(i));
    if (GETARG_C(i)) goto LUA_AOT_SKIP1;  /* skip next instruction (if C) */
  }
  
  // 21	[8]	LOADBOOL 	3 0 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 21)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_22
  label_20 : {
    aot_vmfetch(0x00000185);
    setbvalue(s2v(ra), GETARG_B(i));
    if (GETARG_C(i)) goto LUA_AOT_SKIP1;  /* skip next instruction (if C) */
  }
  
  // 22	[8]	SETLIST  	1 2 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 22)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_23
  label_21 : {
    aot_vmfetch(0x000200cc);
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
          last += GETARG_Ax(0x000200c6) * (MAXARG_C + 1);
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
  
  // 23	[8]	RETURN1  	1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 23)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_22 : {
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
  
  // 24	[10]	RETURN0  	
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 24)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_23 : {
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
 
// source = @benchmarks/binarytrees/lua.lua
// lines: 12 - 18
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
 
  // 1	[13]	GETI     	1 0 1
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
  
  // 2	[13]	TEST     	1 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #define LUA_AOT_NEXT_JUMP label_15
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x000000c0);
    int cond = !l_isfalse(s2v(ra));
    docondjump();
  }
  
  // 3	[13]	JMP      	12	; to 16
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x800005b6);
    updatetrap(ci);
    goto label_15;
  }
  
  // 4	[14]	GETUPVAL 	1 0	; ItemCheck
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0x00000087);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }
  
  // 5	[14]	GETI     	2 0 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
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
  
  // 6	[14]	CALL     	1 2 2	; 1 in 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_07
  label_05 : {
    aot_vmfetch(0x020200c2);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 7	[14]	ADDI     	1 1 1 
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_08
  label_06 : {
    aot_vmfetch(0x80010093);
    op_arithI(L, l_addi, luai_numadd, TM_ADD, GETARG_k(i));
  }
  
  // 8	[14]	MMBINI   	1 1 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_09
  label_07 : {
    aot_vmfetch(0x068080ad);
    Instruction pi = 0x80010093;  /* original arith. expression */
    int imm = GETARG_sB(i);
    TMS tm = (TMS)GETARG_C(i);
    int flip = GETARG_k(i);
    StkId result = RA(pi);
    Protect(luaT_trybiniTM(L, s2v(ra), imm, flip, result, tm));
  }
  
  // 9	[14]	GETUPVAL 	2 0	; ItemCheck
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 9)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_10
  label_08 : {
    aot_vmfetch(0x00000107);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }
  
  // 10	[14]	GETI     	3 0 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 10)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_11
  label_09 : {
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
  
  // 11	[14]	CALL     	2 2 2	; 1 in 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 11)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_12
  label_10 : {
    aot_vmfetch(0x02020142);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 12	[14]	ADD      	1 1 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 12)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_13
  label_11 : {
    aot_vmfetch(0x020100a0);
    op_arith(L, l_addi, luai_numadd);
  }
  
  // 13	[14]	MMBIN    	1 2 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 13)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_14
  label_12 : {
    aot_vmfetch(0x060200ac);
    Instruction pi = 0x020100a0; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 14	[14]	RETURN1  	1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 14)
  #undef  LUA_AOT_NEXT_JUMP
  #define LUA_AOT_NEXT_JUMP label_17
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_15
  label_13 : {
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
  
  // 15	[14]	JMP      	2	; to 18
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 15)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_16
  label_14 : {
    aot_vmfetch(0x800000b6);
    updatetrap(ci);
    goto label_17;
  }
  
  // 16	[16]	LOADI    	1 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 16)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_17
  label_15 : {
    aot_vmfetch(0x80000081);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }
  
  // 17	[16]	RETURN1  	1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 17)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_16 : {
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
  
  // 18	[18]	RETURN0  	
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 18)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_17 : {
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
 
// source = @benchmarks/binarytrees/lua.lua
// lines: 20 - 28
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
 
  // 1	[21]	SUB      	3 1 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 1)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_02
  label_00 : {
    aot_vmfetch(0x020101a1);
    op_arith(L, l_subi, luai_numsub);
  }
  
  // 2	[21]	MMBIN    	1 2 7	; __sub
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x070200ac);
    Instruction pi = 0x020101a1; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 3	[21]	ADD      	3 3 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x000301a0);
    op_arith(L, l_addi, luai_numadd);
  }
  
  // 4	[21]	MMBIN    	3 0 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0x060001ac);
    Instruction pi = 0x000301a0; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 5	[21]	SHLI     	3 3 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x8003019f);
    TValue *rb = vRB(i);
    int ic = GETARG_sC(i);
    lua_Integer ib;
    if (tointegerns(rb, &ib)) {
       setivalue(s2v(ra), luaV_shiftl(ic, ib));
       goto LUA_AOT_SKIP1;
    }
  }
  
  // 6	[21]	MMBINI   	3 1 16	; __shl
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_07
  label_05 : {
    aot_vmfetch(0x108081ad);
    Instruction pi = 0x8003019f;  /* original arith. expression */
    int imm = GETARG_sB(i);
    TMS tm = (TMS)GETARG_C(i);
    int flip = GETARG_k(i);
    StkId result = RA(pi);
    Protect(luaT_trybiniTM(L, s2v(ra), imm, flip, result, tm));
  }
  
  // 7	[22]	LOADI    	4 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_08
  label_06 : {
    aot_vmfetch(0x7fff8201);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }
  
  // 8	[23]	LOADI    	5 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_09
  label_07 : {
    aot_vmfetch(0x80000281);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }
  
  // 9	[23]	MOVE     	6 3
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 9)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_10
  label_08 : {
    aot_vmfetch(0x00030300);
    setobjs2s(L, ra, RB(i));
  }
  
  // 10	[23]	LOADI    	7 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 10)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_11
  label_09 : {
    aot_vmfetch(0x80000381);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }
  
  // 11	[23]	FORPREP  	5 8	; to 20
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 11)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_12
  label_10 : {
    aot_vmfetch(0x000402c8);
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
        goto label_20; /* skip the loop */
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
        goto label_20; /* skip the loop */
      else {
        /* make sure internal values are all float */
        setfltvalue(plimit, limit);
        setfltvalue(pstep, step);
        setfltvalue(s2v(ra), init);  /* internal index */
        setfltvalue(s2v(ra + 3), init);  /* control variable */
      }
    }
  }
  
  // 12	[24]	GETUPVAL 	9 0	; BottomUpTree
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 12)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_13
  label_11 : {
    aot_vmfetch(0x00000487);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }
  
  // 13	[24]	MOVE     	10 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 13)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_14
  label_12 : {
    aot_vmfetch(0x00020500);
    setobjs2s(L, ra, RB(i));
  }
  
  // 14	[24]	CALL     	9 2 2	; 1 in 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 14)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_15
  label_13 : {
    aot_vmfetch(0x020204c2);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 15	[25]	GETUPVAL 	10 1	; ItemCheck
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 15)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_16
  label_14 : {
    aot_vmfetch(0x00010507);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }
  
  // 16	[25]	MOVE     	11 9
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 16)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_17
  label_15 : {
    aot_vmfetch(0x00090580);
    setobjs2s(L, ra, RB(i));
  }
  
  // 17	[25]	CALL     	10 2 2	; 1 in 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 17)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_18
  label_16 : {
    aot_vmfetch(0x02020542);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 18	[25]	ADD      	4 4 10
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 18)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_19
  label_17 : {
    aot_vmfetch(0x0a040220);
    op_arith(L, l_addi, luai_numadd);
  }
  
  // 19	[25]	MMBIN    	4 10 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 19)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_20
  label_18 : {
    aot_vmfetch(0x060a022c);
    Instruction pi = 0x0a040220; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }
  
  // 20	[23]	FORLOOP  	5 9	; to 12
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 20)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_21
  label_19 : {
    aot_vmfetch(0x000482c7);
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
  
  // 21	[27]	NEWTABLE 	5 0 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 21)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_22
  label_20 : {
    aot_vmfetch(0x02000291);
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
  
  // 22	[27]	EXTRAARG 	0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 22)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_23
  label_21 : {
    aot_vmfetch(0x00000050);
    lua_assert(0);
  }
  
  // 23	[27]	MOVE     	6 3
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 23)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_24
  label_22 : {
    aot_vmfetch(0x00030300);
    setobjs2s(L, ra, RB(i));
  }
  
  // 24	[27]	MOVE     	7 4
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 24)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_25
  label_23 : {
    aot_vmfetch(0x00040380);
    setobjs2s(L, ra, RB(i));
  }
  
  // 25	[27]	SETLIST  	5 2 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 25)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_26
  label_24 : {
    aot_vmfetch(0x000202cc);
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
          last += GETARG_Ax(0x000202c6) * (MAXARG_C + 1);
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
  
  // 26	[27]	RETURN1  	5
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 26)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_25 : {
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
  
  // 27	[28]	RETURN0  	
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 27)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_26 : {
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
 
static AotCompiledFunction LUA_AOT_FUNCTIONS[] = {
  magic_implementation_00,
  magic_implementation_01,
  magic_implementation_02,
  magic_implementation_03,
  NULL
};
 
static const char LUA_AOT_MODULE_SOURCE_CODE[] = {
  108, 111,  99,  97, 108,  32, 102, 117, 110,  99, 116, 105, 111, 110,  32,  66, 
  111, 116, 116, 111, 109,  85, 112,  84, 114, 101, 101,  40, 100, 101, 112, 116, 
  104,  41,  10,  32,  32,  32,  32, 105, 102,  32, 100, 101, 112, 116, 104,  32, 
   62,  32,  48,  32, 116, 104, 101, 110,  10,  32,  32,  32,  32,  32,  32,  32, 
   32, 100, 101, 112, 116, 104,  32,  61,  32, 100, 101, 112, 116, 104,  32,  45, 
   32,  49,  10,  32,  32,  32,  32,  32,  32,  32,  32, 108, 111,  99,  97, 108, 
   32, 108, 101, 102, 116,  32,  32,  61,  32,  66, 111, 116, 116, 111, 109,  85, 
  112,  84, 114, 101, 101,  40, 100, 101, 112, 116, 104,  41,  10,  32,  32,  32, 
   32,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32, 114, 105, 103, 104, 116, 
   32,  61,  32,  66, 111, 116, 116, 111, 109,  85, 112,  84, 114, 101, 101,  40, 
  100, 101, 112, 116, 104,  41,  10,  32,  32,  32,  32,  32,  32,  32,  32, 114, 
  101, 116, 117, 114, 110,  32, 123,  32, 108, 101, 102, 116,  44,  32, 114, 105, 
  103, 104, 116,  32, 125,  10,  32,  32,  32,  32, 101, 108, 115, 101,  10,  32, 
   32,  32,  32,  32,  32,  32,  32, 114, 101, 116, 117, 114, 110,  32, 123,  32, 
  102,  97, 108, 115, 101,  44,  32, 102,  97, 108, 115, 101,  32, 125,  10,  32, 
   32,  32,  32, 101, 110, 100,  10, 101, 110, 100,  10,  10, 108, 111,  99,  97, 
  108,  32, 102, 117, 110,  99, 116, 105, 111, 110,  32,  73, 116, 101, 109,  67, 
  104, 101,  99, 107,  40, 116, 114, 101, 101,  41,  10,  32,  32,  32,  32, 105, 
  102,  32, 116, 114, 101, 101,  91,  49,  93,  32, 116, 104, 101, 110,  10,  32, 
   32,  32,  32,  32,  32,  32,  32, 114, 101, 116, 117, 114, 110,  32,  49,  32, 
   43,  32,  73, 116, 101, 109,  67, 104, 101,  99, 107,  40, 116, 114, 101, 101, 
   91,  49,  93,  41,  32,  43,  32,  73, 116, 101, 109,  67, 104, 101,  99, 107, 
   40, 116, 114, 101, 101,  91,  50,  93,  41,  10,  32,  32,  32,  32, 101, 108, 
  115, 101,  10,  32,  32,  32,  32,  32,  32,  32,  32, 114, 101, 116, 117, 114, 
  110,  32,  49,  10,  32,  32,  32,  32, 101, 110, 100,  10, 101, 110, 100,  10, 
   10, 108, 111,  99,  97, 108,  32, 102, 117, 110,  99, 116, 105, 111, 110,  32, 
   83, 116, 114, 101, 115, 115,  40, 109, 105, 110, 100, 101, 112, 116, 104,  44, 
   32, 109,  97, 120, 100, 101, 112, 116, 104,  44,  32, 100, 101, 112, 116, 104, 
   41,  10,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32, 105, 116, 101, 114, 
   97, 116, 105, 111, 110, 115,  32,  61,  32,  49,  32,  60,  60,  32,  40, 109, 
   97, 120, 100, 101, 112, 116, 104,  32,  45,  32, 100, 101, 112, 116, 104,  32, 
   43,  32, 109, 105, 110, 100, 101, 112, 116, 104,  41,  10,  32,  32,  32,  32, 
  108, 111,  99,  97, 108,  32,  99, 104, 101,  99, 107,  32,  61,  32,  48,  10, 
   32,  32,  32,  32, 102, 111, 114,  32,  95,  32,  61,  32,  49,  44,  32, 105, 
  116, 101, 114,  97, 116, 105, 111, 110, 115,  32, 100, 111,  10,  32,  32,  32, 
   32,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32, 116,  32,  61,  32,  66, 
  111, 116, 116, 111, 109,  85, 112,  84, 114, 101, 101,  40, 100, 101, 112, 116, 
  104,  41,  10,  32,  32,  32,  32,  32,  32,  32,  32,  99, 104, 101,  99, 107, 
   32,  61,  32,  99, 104, 101,  99, 107,  32,  43,  32,  73, 116, 101, 109,  67, 
  104, 101,  99, 107,  40, 116,  41,  10,  32,  32,  32,  32, 101, 110, 100,  10, 
   32,  32,  32,  32, 114, 101, 116, 117, 114, 110,  32, 123,  32, 105, 116, 101, 
  114,  97, 116, 105, 111, 110, 115,  44,  32,  99, 104, 101,  99, 107,  32, 125, 
   10, 101, 110, 100,  10,  10, 114, 101, 116, 117, 114, 110,  32, 123,  10,  32, 
   32,  32,  32,  66, 111, 116, 116, 111, 109,  85, 112,  84, 114, 101, 101,  32, 
   61,  32,  66, 111, 116, 116, 111, 109,  85, 112,  84, 114, 101, 101,  44,  10, 
   32,  32,  32,  32,  73, 116, 101, 109,  67, 104, 101,  99, 107,  32,  61,  32, 
   73, 116, 101, 109,  67, 104, 101,  99, 107,  44,  10,  32,  32,  32,  32,  83, 
  116, 114, 101, 115, 115,  32,  61,  32,  83, 116, 114, 101, 115, 115,  44,  10, 
  125,  10,   0
};
 
#define LUA_AOT_LUAOPEN_NAME luaopen_benchmarks_binarytrees_luaot
 
#include "luaot_footer.c"
