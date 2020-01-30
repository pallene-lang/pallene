#include "luaot_header.c"

// source = @benchmarks/fasta/lua.lua
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

  // 2	[1]	LOADK    	0 0	; 139968
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x00000003);
    TValue *rb = k + GETARG_Bx(i);
    setobj2s(L, ra, rb);
  }

  // 3	[2]	LOADI    	1 3877
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x87920081);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 4	[3]	LOADI    	2 29573
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0xb9c20101);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 5	[5]	LOADI    	3 42
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x80148181);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 6	[9]	CLOSURE  	4 0	; 0x1a8c360
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_07
  label_05 : {
    aot_vmfetch(0x0000024d);
    Proto *p = cl->p->p[GETARG_Bx(i)];
    halfProtect(pushclosure(L, p, cl->upvals, base, ra));
    checkGC(L, ra + 1);
  }

  // 7	[11]	LOADI    	5 60
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_08
  label_06 : {
    aot_vmfetch(0x801d8281);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 8	[15]	CLOSURE  	6 1	; 0x1a8c6c0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_09
  label_07 : {
    aot_vmfetch(0x0000834d);
    Proto *p = cl->p->p[GETARG_Bx(i)];
    halfProtect(pushclosure(L, p, cl->upvals, base, ra));
    checkGC(L, ra + 1);
  }

  // 9	[40]	CLOSURE  	7 2	; 0x1a8cf10
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 9)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_10
  label_08 : {
    aot_vmfetch(0x000103cd);
    Proto *p = cl->p->p[GETARG_Bx(i)];
    halfProtect(pushclosure(L, p, cl->upvals, base, ra));
    checkGC(L, ra + 1);
  }

  // 10	[49]	CLOSURE  	8 3	; 0x1a8c2a0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 10)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_11
  label_09 : {
    aot_vmfetch(0x0001844d);
    Proto *p = cl->p->p[GETARG_Bx(i)];
    halfProtect(pushclosure(L, p, cl->upvals, base, ra));
    checkGC(L, ra + 1);
  }

  // 11	[87]	CLOSURE  	9 4	; 0x1a8d110
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 11)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_12
  label_10 : {
    aot_vmfetch(0x000204cd);
    Proto *p = cl->p->p[GETARG_Bx(i)];
    halfProtect(pushclosure(L, p, cl->upvals, base, ra));
    checkGC(L, ra + 1);
  }

  // 12	[89]	NEWTABLE 	10 2 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 12)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_13
  label_11 : {
    aot_vmfetch(0x00020511);
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

  // 13	[89]	EXTRAARG 	0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 13)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_14
  label_12 : {
    aot_vmfetch(0x00000050);
    lua_assert(0);
  }

  // 14	[90]	SETFIELD 	10 1 7	; "repeat_fasta"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 14)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_15
  label_13 : {
    aot_vmfetch(0x07010510);
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

  // 15	[91]	SETFIELD 	10 2 9	; "random_fasta"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 15)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_16
  label_14 : {
    aot_vmfetch(0x09020510);
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

  // 16	[92]	RETURN   	10 2 1	; 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 16)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_15 : {
    aot_vmfetch(0x01028544);
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

  // 17	[92]	RETURN   	10 1 1	; 0 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 17)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_16 : {
    aot_vmfetch(0x01018544);
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

// source = @benchmarks/fasta/lua.lua
// lines: 6 - 9
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

  // 1	[7]	GETUPVAL 	1 0	; seed
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

  // 2	[7]	GETUPVAL 	2 1	; IA
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

  // 3	[7]	MUL      	1 1 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x020100a2);
    op_arith(L, l_muli, luai_nummul);
  }

  // 4	[7]	MMBIN    	1 2 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0x080200ac);
    Instruction pi = 0x020100a2; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }

  // 5	[7]	GETUPVAL 	2 2	; IC
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x00020107);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }

  // 6	[7]	ADD      	1 1 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_07
  label_05 : {
    aot_vmfetch(0x020100a0);
    op_arith(L, l_addi, luai_numadd);
  }

  // 7	[7]	MMBIN    	1 2 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_08
  label_06 : {
    aot_vmfetch(0x060200ac);
    Instruction pi = 0x020100a0; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }

  // 8	[7]	GETUPVAL 	2 3	; IM
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_09
  label_07 : {
    aot_vmfetch(0x00030107);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }

  // 9	[7]	MOD      	1 1 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 9)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_10
  label_08 : {
    aot_vmfetch(0x020100a3);
    op_arith(L, luaV_mod, luaV_modf);
  }

  // 10	[7]	MMBIN    	1 2 9	; __mod
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 10)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_11
  label_09 : {
    aot_vmfetch(0x090200ac);
    Instruction pi = 0x020100a3; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }

  // 11	[7]	SETUPVAL 	1 0	; seed
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 11)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_12
  label_10 : {
    aot_vmfetch(0x00000088);
    UpVal *uv = cl->upvals[GETARG_B(i)];
    setobj(L, uv->v, s2v(ra));
    luaC_barrier(L, uv, s2v(ra));
  }

  // 12	[8]	GETUPVAL 	1 0	; seed
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 12)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_13
  label_11 : {
    aot_vmfetch(0x00000087);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }

  // 13	[8]	MUL      	1 0 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 13)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_14
  label_12 : {
    aot_vmfetch(0x010000a2);
    op_arith(L, l_muli, luai_nummul);
  }

  // 14	[8]	MMBIN    	0 1 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 14)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_15
  label_13 : {
    aot_vmfetch(0x0801002c);
    Instruction pi = 0x010000a2; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }

  // 15	[8]	GETUPVAL 	2 3	; IM
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 15)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_16
  label_14 : {
    aot_vmfetch(0x00030107);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }

  // 16	[8]	DIV      	1 1 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 16)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_17
  label_15 : {
    aot_vmfetch(0x020100a5);
    op_arithf(L, luai_numdiv);
  }

  // 17	[8]	MMBIN    	1 2 11	; __div
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 17)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_18
  label_16 : {
    aot_vmfetch(0x0b0200ac);
    Instruction pi = 0x020100a5; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }

  // 18	[8]	RETURN1  	1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 18)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_17 : {
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

  // 19	[9]	RETURN0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 19)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_18 : {
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

// source = @benchmarks/fasta/lua.lua
// lines: 13 - 15
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

  // 1	[14]	GETTABUP 	2 0 0	; _ENV "io"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 1)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_02
  label_00 : {
    aot_vmfetch(0x00000109);
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

  // 2	[14]	GETFIELD 	2 2 1	; "write"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x0102010c);
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

  // 3	[14]	LOADK    	3 2	; ">"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x00010183);
    TValue *rb = k + GETARG_Bx(i);
    setobj2s(L, ra, rb);
  }

  // 4	[14]	MOVE     	4 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0x00000200);
    setobjs2s(L, ra, RB(i));
  }

  // 5	[14]	LOADK    	5 3	; " "
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x00018283);
    TValue *rb = k + GETARG_Bx(i);
    setobj2s(L, ra, rb);
  }

  // 6	[14]	MOVE     	6 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_07
  label_05 : {
    aot_vmfetch(0x00010300);
    setobjs2s(L, ra, RB(i));
  }

  // 7	[14]	LOADK    	7 4	; "\n"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_08
  label_06 : {
    aot_vmfetch(0x00020383);
    TValue *rb = k + GETARG_Bx(i);
    setobj2s(L, ra, rb);
  }

  // 8	[14]	CONCAT   	3 5
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_09
  label_07 : {
    aot_vmfetch(0x000501b3);
    int n = GETARG_B(i);  /* number of elements to concatenate */
    L->top = ra + n;  /* mark the end of concat operands */
    ProtectNT(luaV_concat(L, n));
    checkGC(L, L->top); /* 'luaV_concat' ensures correct top */
  }

  // 9	[14]	CALL     	2 2 1	; 1 in 0 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 9)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_08 : {
    aot_vmfetch(0x01020142);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }

  // 10	[15]	RETURN0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 10)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_09 : {
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

// source = @benchmarks/fasta/lua.lua
// lines: 17 - 40
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

  // 1	[18]	GETUPVAL 	4 0	; print_fasta_header
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 1)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_02
  label_00 : {
    aot_vmfetch(0x00000207);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }

  // 2	[18]	MOVE     	5 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x00000280);
    setobjs2s(L, ra, RB(i));
  }

  // 3	[18]	MOVE     	6 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x00010300);
    setobjs2s(L, ra, RB(i));
  }

  // 4	[18]	CALL     	4 3 1	; 2 in 0 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0x01030242);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }

  // 5	[20]	LEN      	4 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x00020232);
    Protect(luaV_objlen(L, ra, vRB(i)));
  }

  // 6	[22]	MOVE     	5 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_07
  label_05 : {
    aot_vmfetch(0x00020280);
    setobjs2s(L, ra, RB(i));
  }

  // 7	[22]	MOVE     	6 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_08
  label_06 : {
    aot_vmfetch(0x00020300);
    setobjs2s(L, ra, RB(i));
  }

  // 8	[22]	CONCAT   	5 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_09
  label_07 : {
    aot_vmfetch(0x000202b3);
    int n = GETARG_B(i);  /* number of elements to concatenate */
    L->top = ra + n;  /* mark the end of concat operands */
    ProtectNT(luaV_concat(L, n));
    checkGC(L, L->top); /* 'luaV_concat' ensures correct top */
  }

  // 9	[23]	LEN      	6 5
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 9)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_10
  label_08 : {
    aot_vmfetch(0x00050332);
    Protect(luaV_objlen(L, ra, vRB(i)));
  }

  // 10	[23]	GETUPVAL 	7 1	; WIDTH
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 10)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_11
  label_09 : {
    aot_vmfetch(0x00010387);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }

  // 11	[23]	ADD      	7 4 7
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 11)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_12
  label_10 : {
    aot_vmfetch(0x070403a0);
    op_arith(L, l_addi, luai_numadd);
  }

  // 12	[23]	MMBIN    	4 7 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 12)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_13
  label_11 : {
    aot_vmfetch(0x0607022c);
    Instruction pi = 0x070403a0; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }

  // 13	[23]	LT       	6 7 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 13)
  #undef  LUA_AOT_NEXT_JUMP
  #define LUA_AOT_NEXT_JUMP label_19
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_14
  label_12 : {
    aot_vmfetch(0x00070338);
    op_order(L, l_lti, LTnum, lessthanothers);
  }

  // 14	[23]	JMP      	5	; to 20
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 14)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_15
  label_13 : {
    aot_vmfetch(0x80000236);
    updatetrap(ci);
    goto label_19;
  }

  // 15	[24]	MOVE     	6 5
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 15)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_16
  label_14 : {
    aot_vmfetch(0x00050300);
    setobjs2s(L, ra, RB(i));
  }

  // 16	[24]	MOVE     	7 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 16)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_17
  label_15 : {
    aot_vmfetch(0x00020380);
    setobjs2s(L, ra, RB(i));
  }

  // 17	[24]	CONCAT   	6 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 17)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_18
  label_16 : {
    aot_vmfetch(0x00020333);
    int n = GETARG_B(i);  /* number of elements to concatenate */
    L->top = ra + n;  /* mark the end of concat operands */
    ProtectNT(luaV_concat(L, n));
    checkGC(L, L->top); /* 'luaV_concat' ensures correct top */
  }

  // 18	[24]	MOVE     	5 6
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 18)
  #undef  LUA_AOT_NEXT_JUMP
  #define LUA_AOT_NEXT_JUMP label_08
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_19
  label_17 : {
    aot_vmfetch(0x00060280);
    setobjs2s(L, ra, RB(i));
  }

  // 19	[24]	JMP      	-11	; to 9
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 19)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_20
  label_18 : {
    aot_vmfetch(0x7ffffa36);
    updatetrap(ci);
    goto label_08;
  }

  // 20	[27]	GETUPVAL 	6 1	; WIDTH
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 20)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_21
  label_19 : {
    aot_vmfetch(0x00010307);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }

  // 21	[27]	IDIV     	6 3 6
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 21)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_22
  label_20 : {
    aot_vmfetch(0x06030326);
    op_arith(L, luaV_idiv, luai_numidiv);
  }

  // 22	[27]	MMBIN    	3 6 12	; __idiv
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 22)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_23
  label_21 : {
    aot_vmfetch(0x0c0601ac);
    Instruction pi = 0x06030326; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }

  // 23	[28]	GETUPVAL 	7 1	; WIDTH
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 23)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_24
  label_22 : {
    aot_vmfetch(0x00010387);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }

  // 24	[28]	MOD      	7 3 7
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 24)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_25
  label_23 : {
    aot_vmfetch(0x070303a3);
    op_arith(L, luaV_mod, luaV_modf);
  }

  // 25	[28]	MMBIN    	3 7 9	; __mod
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 25)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_26
  label_24 : {
    aot_vmfetch(0x090701ac);
    Instruction pi = 0x070303a3; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }

  // 26	[29]	LOADI    	8 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 26)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_27
  label_25 : {
    aot_vmfetch(0x7fff8401);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 27	[30]	LOADI    	9 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 27)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_28
  label_26 : {
    aot_vmfetch(0x80000481);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 28	[30]	MOVE     	10 6
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 28)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_29
  label_27 : {
    aot_vmfetch(0x00060500);
    setobjs2s(L, ra, RB(i));
  }

  // 29	[30]	LOADI    	11 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 29)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_30
  label_28 : {
    aot_vmfetch(0x80000581);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 30	[30]	FORPREP  	9 19	; to 50
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 30)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_31
  label_29 : {
    aot_vmfetch(0x000984c8);
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
        goto label_50; /* skip the loop */
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
        goto label_50; /* skip the loop */
      else {
        /* make sure internal values are all float */
        setfltvalue(plimit, limit);
        setfltvalue(pstep, step);
        setfltvalue(s2v(ra), init);  /* internal index */
        setfltvalue(s2v(ra + 3), init);  /* control variable */
      }
    }
  }

  // 31	[31]	GETUPVAL 	13 1	; WIDTH
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 31)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_32
  label_30 : {
    aot_vmfetch(0x00010687);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }

  // 32	[31]	ADD      	13 8 13
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 32)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_33
  label_31 : {
    aot_vmfetch(0x0d0806a0);
    op_arith(L, l_addi, luai_numadd);
  }

  // 33	[31]	MMBIN    	8 13 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 33)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_34
  label_32 : {
    aot_vmfetch(0x060d042c);
    Instruction pi = 0x0d0806a0; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }

  // 34	[32]	GETTABUP 	14 2 0	; _ENV "io"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 34)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_35
  label_33 : {
    aot_vmfetch(0x00020709);
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

  // 35	[32]	GETFIELD 	14 14 1	; "write"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 35)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_36
  label_34 : {
    aot_vmfetch(0x010e070c);
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

  // 36	[32]	GETTABUP 	15 2 2	; _ENV "string"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 36)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_37
  label_35 : {
    aot_vmfetch(0x02020789);
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

  // 37	[32]	GETFIELD 	15 15 3	; "sub"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 37)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_38
  label_36 : {
    aot_vmfetch(0x030f078c);
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

  // 38	[32]	MOVE     	16 5
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 38)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_39
  label_37 : {
    aot_vmfetch(0x00050800);
    setobjs2s(L, ra, RB(i));
  }

  // 39	[32]	ADDI     	17 8 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 39)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_40
  label_38 : {
    aot_vmfetch(0x80080893);
    op_arithI(L, l_addi, luai_numadd, TM_ADD, GETARG_k(i));
  }

  // 40	[32]	MMBINI   	8 1 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 40)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_41
  label_39 : {
    aot_vmfetch(0x0680042d);
    Instruction pi = 0x80080893;  /* original arith. expression */
    int imm = GETARG_sB(i);
    TMS tm = (TMS)GETARG_C(i);
    int flip = GETARG_k(i);
    StkId result = RA(pi);
    Protect(luaT_trybiniTM(L, s2v(ra), imm, flip, result, tm));
  }

  // 41	[32]	MOVE     	18 13
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 41)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_42
  label_40 : {
    aot_vmfetch(0x000d0900);
    setobjs2s(L, ra, RB(i));
  }

  // 42	[32]	CALL     	15 4 0	; 3 in all out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 42)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_43
  label_41 : {
    aot_vmfetch(0x000407c2);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }

  // 43	[32]	CALL     	14 0 1	; all in 0 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 43)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_44
  label_42 : {
    aot_vmfetch(0x01000742);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }

  // 44	[33]	GETTABUP 	14 2 0	; _ENV "io"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 44)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_45
  label_43 : {
    aot_vmfetch(0x00020709);
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

  // 45	[33]	GETFIELD 	14 14 1	; "write"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 45)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_46
  label_44 : {
    aot_vmfetch(0x010e070c);
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

  // 46	[33]	LOADK    	15 4	; "\n"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 46)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_47
  label_45 : {
    aot_vmfetch(0x00020783);
    TValue *rb = k + GETARG_Bx(i);
    setobj2s(L, ra, rb);
  }

  // 47	[33]	CALL     	14 2 1	; 1 in 0 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 47)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_48
  label_46 : {
    aot_vmfetch(0x01020742);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }

  // 48	[34]	MOD      	8 13 4
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 48)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_49
  label_47 : {
    aot_vmfetch(0x040d0423);
    op_arith(L, luaV_mod, luaV_modf);
  }

  // 49	[34]	MMBIN    	13 4 9	; __mod
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 49)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_50
  label_48 : {
    aot_vmfetch(0x090406ac);
    Instruction pi = 0x040d0423; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }

  // 50	[30]	FORLOOP  	9 20	; to 31
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 50)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_51
  label_49 : {
    aot_vmfetch(0x000a04c7);
    if (ttisinteger(s2v(ra + 2))) {  /* integer loop? */
      lua_Unsigned count = l_castS2U(ivalue(s2v(ra + 1)));
      if (count > 0) {  /* still more iterations? */
        lua_Integer step = ivalue(s2v(ra + 2));
        lua_Integer idx = ivalue(s2v(ra));  /* internal index */
        chgivalue(s2v(ra + 1), count - 1);  /* update counter */
        idx = intop(+, idx, step);  /* add step to index */
        chgivalue(s2v(ra), idx);  /* update internal index */
        setivalue(s2v(ra + 3), idx);  /* and control variable */
        goto label_30; /* jump back */
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
        goto label_30; /* jump back */
      }
    }
    updatetrap(ci);  /* allows a signal to break the loop */
  }

  // 51	[36]	GTI      	7 0 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 51)
  #undef  LUA_AOT_NEXT_JUMP
  #define LUA_AOT_NEXT_JUMP label_67
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_52
  label_50 : {
    aot_vmfetch(0x007f03be);
    op_orderI(L, l_gti, luai_numgt, 1, TM_LT);
  }

  // 52	[36]	JMP      	15	; to 68
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 52)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_53
  label_51 : {
    aot_vmfetch(0x80000736);
    updatetrap(ci);
    goto label_67;
  }

  // 53	[37]	GETTABUP 	9 2 0	; _ENV "io"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 53)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_54
  label_52 : {
    aot_vmfetch(0x00020489);
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

  // 54	[37]	GETFIELD 	9 9 1	; "write"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 54)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_55
  label_53 : {
    aot_vmfetch(0x0109048c);
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

  // 55	[37]	GETTABUP 	10 2 2	; _ENV "string"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 55)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_56
  label_54 : {
    aot_vmfetch(0x02020509);
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

  // 56	[37]	GETFIELD 	10 10 3	; "sub"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 56)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_57
  label_55 : {
    aot_vmfetch(0x030a050c);
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

  // 57	[37]	MOVE     	11 5
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 57)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_58
  label_56 : {
    aot_vmfetch(0x00050580);
    setobjs2s(L, ra, RB(i));
  }

  // 58	[37]	ADDI     	12 8 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 58)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_59
  label_57 : {
    aot_vmfetch(0x80080613);
    op_arithI(L, l_addi, luai_numadd, TM_ADD, GETARG_k(i));
  }

  // 59	[37]	MMBINI   	8 1 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 59)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_60
  label_58 : {
    aot_vmfetch(0x0680042d);
    Instruction pi = 0x80080613;  /* original arith. expression */
    int imm = GETARG_sB(i);
    TMS tm = (TMS)GETARG_C(i);
    int flip = GETARG_k(i);
    StkId result = RA(pi);
    Protect(luaT_trybiniTM(L, s2v(ra), imm, flip, result, tm));
  }

  // 60	[37]	ADD      	13 8 7
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 60)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_61
  label_59 : {
    aot_vmfetch(0x070806a0);
    op_arith(L, l_addi, luai_numadd);
  }

  // 61	[37]	MMBIN    	8 7 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 61)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_62
  label_60 : {
    aot_vmfetch(0x0607042c);
    Instruction pi = 0x070806a0; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }

  // 62	[37]	CALL     	10 4 0	; 3 in all out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 62)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_63
  label_61 : {
    aot_vmfetch(0x00040542);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }

  // 63	[37]	CALL     	9 0 1	; all in 0 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 63)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_64
  label_62 : {
    aot_vmfetch(0x010004c2);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }

  // 64	[38]	GETTABUP 	9 2 0	; _ENV "io"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 64)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_65
  label_63 : {
    aot_vmfetch(0x00020489);
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

  // 65	[38]	GETFIELD 	9 9 1	; "write"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 65)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_66
  label_64 : {
    aot_vmfetch(0x0109048c);
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

  // 66	[38]	LOADK    	10 4	; "\n"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 66)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_67
  label_65 : {
    aot_vmfetch(0x00020503);
    TValue *rb = k + GETARG_Bx(i);
    setobj2s(L, ra, rb);
  }

  // 67	[38]	CALL     	9 2 1	; 1 in 0 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 67)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_66 : {
    aot_vmfetch(0x010204c2);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }

  // 68	[40]	RETURN0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 68)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_67 : {
    aot_vmfetch(0x000104c5);
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

// source = @benchmarks/fasta/lua.lua
// lines: 42 - 49
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

  // 1	[43]	LOADI    	2 1
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

  // 2	[43]	LEN      	3 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x000001b2);
    Protect(luaV_objlen(L, ra, vRB(i)));
  }

  // 3	[43]	LOADI    	4 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x80000201);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 4	[43]	FORPREP  	2 4	; to 9
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
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

  // 5	[44]	GETTABLE 	6 0 5
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x0500030a);
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

  // 6	[44]	LE       	1 6 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #define LUA_AOT_NEXT_JUMP label_08
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_07
  label_05 : {
    aot_vmfetch(0x000600b9);
    op_order(L, l_lei, LEnum, lessequalothers);
  }

  // 7	[44]	JMP      	1	; to 9
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_08
  label_06 : {
    aot_vmfetch(0x80000036);
    updatetrap(ci);
    goto label_08;
  }

  // 8	[45]	RETURN1  	5
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_09
  label_07 : {
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

  // 9	[43]	FORLOOP  	2 5	; to 5
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 9)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_10
  label_08 : {
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

  // 10	[48]	LOADI    	2 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 10)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_11
  label_09 : {
    aot_vmfetch(0x80000101);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 11	[48]	RETURN1  	2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 11)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_10 : {
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

  // 12	[49]	RETURN0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 12)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_11 : {
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

// source = @benchmarks/fasta/lua.lua
// lines: 51 - 87
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

  // 1	[52]	GETUPVAL 	4 0	; print_fasta_header
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 1)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_02
  label_00 : {
    aot_vmfetch(0x00000207);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }

  // 2	[52]	MOVE     	5 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x00000280);
    setobjs2s(L, ra, RB(i));
  }

  // 3	[52]	MOVE     	6 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x00010300);
    setobjs2s(L, ra, RB(i));
  }

  // 4	[52]	CALL     	4 3 1	; 2 in 0 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0x01030242);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }

  // 5	[55]	LEN      	4 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x00020232);
    Protect(luaV_objlen(L, ra, vRB(i)));
  }

  // 6	[56]	NEWTABLE 	5 0 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_07
  label_05 : {
    aot_vmfetch(0x00000291);
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

  // 7	[56]	EXTRAARG 	0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_08
  label_06 : {
    aot_vmfetch(0x00000050);
    lua_assert(0);
  }

  // 8	[57]	NEWTABLE 	6 0 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_09
  label_07 : {
    aot_vmfetch(0x00000311);
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

  // 9	[57]	EXTRAARG 	0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 9)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_10
  label_08 : {
    aot_vmfetch(0x00000050);
    lua_assert(0);
  }

  // 10	[59]	LOADF    	7 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 10)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_11
  label_09 : {
    aot_vmfetch(0x7fff8382);
    int b = GETARG_sBx(i);
    setfltvalue(s2v(ra), cast_num(b));
  }

  // 11	[60]	LOADI    	8 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 11)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_12
  label_10 : {
    aot_vmfetch(0x80000401);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 12	[60]	MOVE     	9 4
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 12)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_13
  label_11 : {
    aot_vmfetch(0x00040480);
    setobjs2s(L, ra, RB(i));
  }

  // 13	[60]	LOADI    	10 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 13)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_14
  label_12 : {
    aot_vmfetch(0x80000501);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 14	[60]	FORPREP  	8 7	; to 22
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 14)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_15
  label_13 : {
    aot_vmfetch(0x00038448);
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
        goto label_22; /* skip the loop */
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
        goto label_22; /* skip the loop */
      else {
        /* make sure internal values are all float */
        setfltvalue(plimit, limit);
        setfltvalue(pstep, step);
        setfltvalue(s2v(ra), init);  /* internal index */
        setfltvalue(s2v(ra + 3), init);  /* control variable */
      }
    }
  }

  // 15	[61]	GETTABLE 	12 2 11
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 15)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_16
  label_14 : {
    aot_vmfetch(0x0b02060a);
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

  // 16	[62]	GETI     	13 12 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 16)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_17
  label_15 : {
    aot_vmfetch(0x010c068b);
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

  // 17	[63]	GETI     	14 12 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 17)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_18
  label_16 : {
    aot_vmfetch(0x020c070b);
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

  // 18	[64]	ADD      	7 7 14
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 18)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_19
  label_17 : {
    aot_vmfetch(0x0e0703a0);
    op_arith(L, l_addi, luai_numadd);
  }

  // 19	[64]	MMBIN    	7 14 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 19)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_20
  label_18 : {
    aot_vmfetch(0x060e03ac);
    Instruction pi = 0x0e0703a0; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }

  // 20	[65]	SETTABLE 	5 11 13
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 20)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_21
  label_19 : {
    aot_vmfetch(0x0d0b028e);
    const TValue *slot;
    TValue *rb = vRB(i);  /* key (table is in 'ra') */
    TValue *rc = RKC(i);  /* value */
    lua_Unsigned n;
    if (ttisinteger(rb)  /* fast track for integers? */
        ? (cast_void(n = ivalue(rb)), luaV_fastgeti(L, s2v(ra), n, slot))
        : luaV_fastget(L, s2v(ra), rb, slot, luaH_get)) {
      luaV_finishfastset(L, s2v(ra), slot, rc);
    }
    else
      Protect(luaV_finishset(L, s2v(ra), rb, rc, slot));
  }

  // 21	[66]	SETTABLE 	6 11 7
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 21)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_22
  label_20 : {
    aot_vmfetch(0x070b030e);
    const TValue *slot;
    TValue *rb = vRB(i);  /* key (table is in 'ra') */
    TValue *rc = RKC(i);  /* value */
    lua_Unsigned n;
    if (ttisinteger(rb)  /* fast track for integers? */
        ? (cast_void(n = ivalue(rb)), luaV_fastgeti(L, s2v(ra), n, slot))
        : luaV_fastget(L, s2v(ra), rb, slot, luaH_get)) {
      luaV_finishfastset(L, s2v(ra), slot, rc);
    }
    else
      Protect(luaV_finishset(L, s2v(ra), rb, rc, slot));
  }

  // 22	[60]	FORLOOP  	8 8	; to 15
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 22)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_23
  label_21 : {
    aot_vmfetch(0x00040447);
    if (ttisinteger(s2v(ra + 2))) {  /* integer loop? */
      lua_Unsigned count = l_castS2U(ivalue(s2v(ra + 1)));
      if (count > 0) {  /* still more iterations? */
        lua_Integer step = ivalue(s2v(ra + 2));
        lua_Integer idx = ivalue(s2v(ra));  /* internal index */
        chgivalue(s2v(ra + 1), count - 1);  /* update counter */
        idx = intop(+, idx, step);  /* add step to index */
        chgivalue(s2v(ra), idx);  /* update internal index */
        setivalue(s2v(ra + 3), idx);  /* and control variable */
        goto label_14; /* jump back */
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
        goto label_14; /* jump back */
      }
    }
    updatetrap(ci);  /* allows a signal to break the loop */
  }

  // 23	[68]	SETTABLE 	6 4 0k	; 1.0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 23)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_24
  label_22 : {
    aot_vmfetch(0x0004830e);
    const TValue *slot;
    TValue *rb = vRB(i);  /* key (table is in 'ra') */
    TValue *rc = RKC(i);  /* value */
    lua_Unsigned n;
    if (ttisinteger(rb)  /* fast track for integers? */
        ? (cast_void(n = ivalue(rb)), luaV_fastgeti(L, s2v(ra), n, slot))
        : luaV_fastget(L, s2v(ra), rb, slot, luaH_get)) {
      luaV_finishfastset(L, s2v(ra), slot, rc);
    }
    else
      Protect(luaV_finishset(L, s2v(ra), rb, rc, slot));
  }

  // 24	[72]	LOADI    	7 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 24)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_25
  label_23 : {
    aot_vmfetch(0x7fff8381);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 25	[73]	LOADI    	8 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 25)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_26
  label_24 : {
    aot_vmfetch(0x80000401);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 26	[73]	MOVE     	9 3
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 26)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_27
  label_25 : {
    aot_vmfetch(0x00030480);
    setobjs2s(L, ra, RB(i));
  }

  // 27	[73]	LOADI    	10 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 27)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_28
  label_26 : {
    aot_vmfetch(0x80000501);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 28	[73]	FORPREP  	8 21	; to 50
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 28)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_29
  label_27 : {
    aot_vmfetch(0x000a8448);
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
        goto label_50; /* skip the loop */
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
        goto label_50; /* skip the loop */
      else {
        /* make sure internal values are all float */
        setfltvalue(plimit, limit);
        setfltvalue(pstep, step);
        setfltvalue(s2v(ra), init);  /* internal index */
        setfltvalue(s2v(ra + 3), init);  /* control variable */
      }
    }
  }

  // 29	[74]	GETUPVAL 	12 1	; linear_search
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 29)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_30
  label_28 : {
    aot_vmfetch(0x00010607);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }

  // 30	[74]	MOVE     	13 6
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 30)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_31
  label_29 : {
    aot_vmfetch(0x00060680);
    setobjs2s(L, ra, RB(i));
  }

  // 31	[74]	GETUPVAL 	14 2	; random
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 31)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_32
  label_30 : {
    aot_vmfetch(0x00020707);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }

  // 32	[74]	LOADF    	15 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 32)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_33
  label_31 : {
    aot_vmfetch(0x80000782);
    int b = GETARG_sBx(i);
    setfltvalue(s2v(ra), cast_num(b));
  }

  // 33	[74]	CALL     	14 2 0	; 1 in all out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 33)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_34
  label_32 : {
    aot_vmfetch(0x00020742);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }

  // 34	[74]	CALL     	12 0 2	; all in 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 34)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_35
  label_33 : {
    aot_vmfetch(0x02000642);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }

  // 35	[75]	GETTABLE 	13 5 12
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 35)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_36
  label_34 : {
    aot_vmfetch(0x0c05068a);
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

  // 36	[77]	GETTABUP 	14 3 1	; _ENV "io"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 36)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_37
  label_35 : {
    aot_vmfetch(0x01030709);
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

  // 37	[77]	GETFIELD 	14 14 2	; "write"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 37)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_38
  label_36 : {
    aot_vmfetch(0x020e070c);
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

  // 38	[77]	MOVE     	15 13
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 38)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_39
  label_37 : {
    aot_vmfetch(0x000d0780);
    setobjs2s(L, ra, RB(i));
  }

  // 39	[77]	CALL     	14 2 1	; 1 in 0 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 39)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_40
  label_38 : {
    aot_vmfetch(0x01020742);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }

  // 40	[78]	ADDI     	7 7 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 40)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_41
  label_39 : {
    aot_vmfetch(0x80070393);
    op_arithI(L, l_addi, luai_numadd, TM_ADD, GETARG_k(i));
  }

  // 41	[78]	MMBINI   	7 1 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 41)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_42
  label_40 : {
    aot_vmfetch(0x068003ad);
    Instruction pi = 0x80070393;  /* original arith. expression */
    int imm = GETARG_sB(i);
    TMS tm = (TMS)GETARG_C(i);
    int flip = GETARG_k(i);
    StkId result = RA(pi);
    Protect(luaT_trybiniTM(L, s2v(ra), imm, flip, result, tm));
  }

  // 42	[79]	GETUPVAL 	14 4	; WIDTH
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 42)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_43
  label_41 : {
    aot_vmfetch(0x00040707);
    int b = GETARG_B(i);
    setobj2s(L, ra, cl->upvals[b]->v);
  }

  // 43	[79]	LE       	14 7 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 43)
  #undef  LUA_AOT_NEXT_JUMP
  #define LUA_AOT_NEXT_JUMP label_49
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_44
  label_42 : {
    aot_vmfetch(0x00070739);
    op_order(L, l_lei, LEnum, lessequalothers);
  }

  // 44	[79]	JMP      	5	; to 50
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 44)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_45
  label_43 : {
    aot_vmfetch(0x80000236);
    updatetrap(ci);
    goto label_49;
  }

  // 45	[80]	GETTABUP 	14 3 1	; _ENV "io"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 45)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_46
  label_44 : {
    aot_vmfetch(0x01030709);
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

  // 46	[80]	GETFIELD 	14 14 2	; "write"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 46)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_47
  label_45 : {
    aot_vmfetch(0x020e070c);
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

  // 47	[80]	LOADK    	15 3	; "\n"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 47)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_48
  label_46 : {
    aot_vmfetch(0x00018783);
    TValue *rb = k + GETARG_Bx(i);
    setobj2s(L, ra, rb);
  }

  // 48	[80]	CALL     	14 2 1	; 1 in 0 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 48)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_49
  label_47 : {
    aot_vmfetch(0x01020742);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }

  // 49	[81]	LOADI    	7 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 49)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_50
  label_48 : {
    aot_vmfetch(0x7fff8381);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 50	[73]	FORLOOP  	8 22	; to 29
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 50)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_51
  label_49 : {
    aot_vmfetch(0x000b0447);
    if (ttisinteger(s2v(ra + 2))) {  /* integer loop? */
      lua_Unsigned count = l_castS2U(ivalue(s2v(ra + 1)));
      if (count > 0) {  /* still more iterations? */
        lua_Integer step = ivalue(s2v(ra + 2));
        lua_Integer idx = ivalue(s2v(ra));  /* internal index */
        chgivalue(s2v(ra + 1), count - 1);  /* update counter */
        idx = intop(+, idx, step);  /* add step to index */
        chgivalue(s2v(ra), idx);  /* update internal index */
        setivalue(s2v(ra + 3), idx);  /* and control variable */
        goto label_28; /* jump back */
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
        goto label_28; /* jump back */
      }
    }
    updatetrap(ci);  /* allows a signal to break the loop */
  }

  // 51	[84]	GTI      	7 0 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 51)
  #undef  LUA_AOT_NEXT_JUMP
  #define LUA_AOT_NEXT_JUMP label_56
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_52
  label_50 : {
    aot_vmfetch(0x007f03be);
    op_orderI(L, l_gti, luai_numgt, 1, TM_LT);
  }

  // 52	[84]	JMP      	4	; to 57
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 52)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_53
  label_51 : {
    aot_vmfetch(0x800001b6);
    updatetrap(ci);
    goto label_56;
  }

  // 53	[85]	GETTABUP 	8 3 1	; _ENV "io"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 53)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_54
  label_52 : {
    aot_vmfetch(0x01030409);
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

  // 54	[85]	GETFIELD 	8 8 2	; "write"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 54)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_55
  label_53 : {
    aot_vmfetch(0x0208040c);
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

  // 55	[85]	LOADK    	9 3	; "\n"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 55)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_56
  label_54 : {
    aot_vmfetch(0x00018483);
    TValue *rb = k + GETARG_Bx(i);
    setobj2s(L, ra, rb);
  }

  // 56	[85]	CALL     	8 2 1	; 1 in 0 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 56)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_55 : {
    aot_vmfetch(0x01020442);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }

  // 57	[87]	RETURN0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 57)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_56 : {
    aot_vmfetch(0x00010445);
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
#if 0
  108, 111,  99,  97, 108,  32,  73,  77,  32,  32,  32,  61,  32,  49,  51,  57,
   57,  54,  56,  10, 108, 111,  99,  97, 108,  32,  73,  65,  32,  32,  32,  61,
   32,  51,  56,  55,  55,  10, 108, 111,  99,  97, 108,  32,  73,  67,  32,  32,
   32,  61,  32,  50,  57,  53,  55,  51,  10,  10, 108, 111,  99,  97, 108,  32,
  115, 101, 101, 100,  32,  61,  32,  52,  50,  10, 108, 111,  99,  97, 108,  32,
  102, 117, 110,  99, 116, 105, 111, 110,  32, 114,  97, 110, 100, 111, 109,  40,
  109,  97, 120,  41,  10,  32,  32,  32,  32, 115, 101, 101, 100,  32,  61,  32,
   40, 115, 101, 101, 100,  32,  42,  32,  73,  65,  32,  43,  32,  73,  67,  41,
   32,  37,  32,  73,  77,  10,  32,  32,  32,  32, 114, 101, 116, 117, 114, 110,
   32, 109,  97, 120,  32,  42,  32, 115, 101, 101, 100,  32,  47,  32,  73,  77,
   59,  10, 101, 110, 100,  10,  10, 108, 111,  99,  97, 108,  32,  87,  73,  68,
   84,  72,  32,  61,  32,  54,  48,  10,  10, 108, 111,  99,  97, 108,  32, 102,
  117, 110,  99, 116, 105, 111, 110,  32, 112, 114, 105, 110, 116,  95, 102,  97,
  115, 116,  97,  95, 104, 101,  97, 100, 101, 114,  40, 105, 100,  44,  32, 100,
  101, 115,  99,  41,  10,  32,  32,  32,  32, 105, 111,  46, 119, 114, 105, 116,
  101,  40,  34,  62,  34,  32,  46,  46,  32, 105, 100,  32,  46,  46,  32,  34,
   32,  34,  32,  46,  46,  32, 100, 101, 115,  99,  32,  46,  46,  32,  34,  92,
  110,  34,  41,  10, 101, 110, 100,  10,  10, 108, 111,  99,  97, 108,  32, 102,
  117, 110,  99, 116, 105, 111, 110,  32, 114, 101, 112, 101,  97, 116,  95, 102,
   97, 115, 116,  97,  40, 105, 100,  44,  32, 100, 101, 115,  99,  44,  32,  97,
  108, 117,  44,  32, 110,  41,  10,  32,  32,  32,  32, 112, 114, 105, 110, 116,
   95, 102,  97, 115, 116,  97,  95, 104, 101,  97, 100, 101, 114,  40, 105, 100,
   44,  32, 100, 101, 115,  99,  41,  10,  10,  32,  32,  32,  32, 108, 111,  99,
   97, 108,  32,  97, 108, 117, 115, 105, 122, 101,  32,  61,  32,  35,  97, 108,
  117,  10,  10,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32,  97, 108, 117,
  119, 114,  97, 112,  32,  61,  32,  97, 108, 117,  32,  46,  46,  32,  97, 108,
  117,  10,  32,  32,  32,  32, 119, 104, 105, 108, 101,  32,  35,  97, 108, 117,
  119, 114,  97, 112,  32,  60,  32,  97, 108, 117, 115, 105, 122, 101,  32,  43,
   32,  87,  73,  68,  84,  72,  32, 100, 111,  10,  32,  32,  32,  32,  32,  32,
   32,  32,  97, 108, 117, 119, 114,  97, 112,  32,  61,  32,  97, 108, 117, 119,
  114,  97, 112,  32,  46,  46,  32,  97, 108, 117,  10,  32,  32,  32,  32, 101,
  110, 100,  10,  10,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32, 108, 105,
  110, 101, 115,  32,  32,  32,  32,  32,  61,  32, 110,  32,  47,  47,  32,  87,
   73,  68,  84,  72,  10,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32, 108,
   97, 115, 116,  95, 108, 105, 110, 101,  32,  61,  32, 110,  32,  37,  32,  87,
   73,  68,  84,  72,  10,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32, 115,
  116,  97, 114, 116,  32,  61,  32,  48,  32,  45,  45,  32,  40,  84, 104, 105,
  115,  32, 105, 110, 100, 101, 120,  32, 105, 115,  32,  48,  45,  98,  97, 115,
  101, 100,  32,  98,  97,  99,  97, 117, 115, 101,  32, 111, 102,  32, 116, 104,
  101,  32,  37,  32, 111, 112, 101, 114,  97, 116, 111, 114,  41,  10,  32,  32,
   32,  32, 102, 111, 114,  32,  95,  32,  61,  32,  49,  44,  32, 108, 105, 110,
  101, 115,  32, 100, 111,  10,  32,  32,  32,  32,  32,  32,  32,  32, 108, 111,
   99,  97, 108,  32, 115, 116, 111, 112,  32,  61,  32, 115, 116,  97, 114, 116,
   32,  43,  32,  87,  73,  68,  84,  72,  10,  32,  32,  32,  32,  32,  32,  32,
   32, 105, 111,  46, 119, 114, 105, 116, 101,  40, 115, 116, 114, 105, 110, 103,
   46, 115, 117,  98,  40,  97, 108, 117, 119, 114,  97, 112,  44,  32, 115, 116,
   97, 114, 116,  43,  49,  44,  32, 115, 116, 111, 112,  41,  41,  10,  32,  32,
   32,  32,  32,  32,  32,  32, 105, 111,  46, 119, 114, 105, 116, 101,  40,  34,
   92, 110,  34,  41,  10,  32,  32,  32,  32,  32,  32,  32,  32, 115, 116,  97,
  114, 116,  32,  61,  32, 115, 116, 111, 112,  32,  37,  32,  97, 108, 117, 115,
  105, 122, 101,  10,  32,  32,  32,  32, 101, 110, 100,  10,  32,  32,  32,  32,
  105, 102,  32, 108,  97, 115, 116,  95, 108, 105, 110, 101,  32,  62,  32,  48,
   32, 116, 104, 101, 110,  10,  32,  32,  32,  32,  32,  32,  32,  32, 105, 111,
   46, 119, 114, 105, 116, 101,  40, 115, 116, 114, 105, 110, 103,  46, 115, 117,
   98,  40,  97, 108, 117, 119, 114,  97, 112,  44,  32, 115, 116,  97, 114, 116,
   43,  49,  44,  32, 115, 116,  97, 114, 116,  32,  43,  32, 108,  97, 115, 116,
   95, 108, 105, 110, 101,  41,  41,  10,  32,  32,  32,  32,  32,  32,  32,  32,
  105, 111,  46, 119, 114, 105, 116, 101,  40,  34,  92, 110,  34,  41,  10,  32,
   32,  32,  32, 101, 110, 100,  10, 101, 110, 100,  10,  10, 108, 111,  99,  97,
  108,  32, 102, 117, 110,  99, 116, 105, 111, 110,  32, 108, 105, 110, 101,  97,
  114,  95, 115, 101,  97, 114,  99, 104,  40, 112, 115,  44,  32, 112,  41,  10,
   32,  32,  32,  32, 102, 111, 114,  32, 105,  32,  61,  32,  49,  44,  32,  35,
  112, 115,  32, 100, 111,  10,  32,  32,  32,  32,  32,  32,  32,  32, 105, 102,
   32, 112, 115,  91, 105,  93,  62,  61,  32, 112,  32, 116, 104, 101, 110,  10,
   32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32, 114, 101, 116, 117,
  114, 110,  32, 105,  10,  32,  32,  32,  32,  32,  32,  32,  32, 101, 110, 100,
   10,  32,  32,  32,  32, 101, 110, 100,  10,  32,  32,  32,  32, 114, 101, 116,
  117, 114, 110,  32,  49,  10, 101, 110, 100,  10,  10, 108, 111,  99,  97, 108,
   32, 102, 117, 110,  99, 116, 105, 111, 110,  32, 114,  97, 110, 100, 111, 109,
   95, 102,  97, 115, 116,  97,  40, 105, 100,  44,  32, 100, 101, 115,  99,  44,
   32, 102, 114, 101, 113, 117, 101, 110,  99, 105, 101, 115,  44,  32, 110,  41,
   10,  32,  32,  32,  32, 112, 114, 105, 110, 116,  95, 102,  97, 115, 116,  97,
   95, 104, 101,  97, 100, 101, 114,  40, 105, 100,  44,  32, 100, 101, 115,  99,
   41,  10,  10,  32,  32,  32,  32,  45,  45,  32,  80, 114, 101, 112,  97, 114,
  101,  32, 116, 104, 101,  32,  99, 117, 109, 109, 117, 108,  97, 116, 105, 118,
  101,  32, 112, 114, 111,  98,  97,  98, 105, 108, 105, 116, 121,  32, 116,  97,
   98, 108, 101,  10,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32, 110, 105,
  116, 101, 109, 115,  32,  32,  61,  32,  35, 102, 114, 101, 113, 117, 101, 110,
   99, 105, 101, 115,  10,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32, 108,
  101, 116, 116, 101, 114, 115,  32,  61,  32, 123, 125,  10,  32,  32,  32,  32,
  108, 111,  99,  97, 108,  32, 112, 114, 111,  98, 115,  32,  32,  32,  61,  32,
  123, 125,  10,  32,  32,  32,  32, 100, 111,  10,  32,  32,  32,  32,  32,  32,
   32,  32, 108, 111,  99,  97, 108,  32, 116, 111, 116,  97, 108,  32,  61,  32,
   48,  46,  48,  10,  32,  32,  32,  32,  32,  32,  32,  32, 102, 111, 114,  32,
  105,  32,  61,  32,  49,  44,  32, 110, 105, 116, 101, 109, 115,  32, 100, 111,
   10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32, 108, 111,  99,
   97, 108,  32, 111,  32,  61,  32, 102, 114, 101, 113, 117, 101, 110,  99, 105,
  101, 115,  91, 105,  93,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,
   32,  32, 108, 111,  99,  97, 108,  32,  99,  32,  61,  32, 111,  91,  49,  93,
   10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32, 108, 111,  99,
   97, 108,  32, 112,  32,  61,  32, 111,  91,  50,  93,  10,  32,  32,  32,  32,
   32,  32,  32,  32,  32,  32,  32,  32, 116, 111, 116,  97, 108,  32,  61,  32,
  116, 111, 116,  97, 108,  32,  43,  32, 112,  10,  32,  32,  32,  32,  32,  32,
   32,  32,  32,  32,  32,  32, 108, 101, 116, 116, 101, 114, 115,  91, 105,  93,
   32,  61,  32,  99,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,
   32, 112, 114, 111,  98, 115,  91, 105,  93,  32,  32,  32,  61,  32, 116, 111,
  116,  97, 108,  10,  32,  32,  32,  32,  32,  32,  32,  32, 101, 110, 100,  10,
   32,  32,  32,  32,  32,  32,  32,  32, 112, 114, 111,  98, 115,  91, 110, 105,
  116, 101, 109, 115,  93,  32,  61,  32,  49,  46,  48,  10,  32,  32,  32,  32,
  101, 110, 100,  10,  10,  32,  32,  32,  32,  45,  45,  32,  71, 101, 110, 101,
  114,  97, 116, 101,  32, 116, 104, 101,  32, 111, 117, 116, 112, 117, 116,  10,
   32,  32,  32,  32, 108, 111,  99,  97, 108,  32,  99, 111, 108,  32,  61,  32,
   48,  10,  32,  32,  32,  32, 102, 111, 114,  32,  95,  32,  61,  32,  49,  44,
   32, 110,  32, 100, 111,  10,  32,  32,  32,  32,  32,  32,  32,  32, 108, 111,
   99,  97, 108,  32, 105, 120,  32,  61,  32, 108, 105, 110, 101,  97, 114,  95,
  115, 101,  97, 114,  99, 104,  40, 112, 114, 111,  98, 115,  44,  32, 114,  97,
  110, 100, 111, 109,  40,  49,  46,  48,  41,  41,  10,  32,  32,  32,  32,  32,
   32,  32,  32, 108, 111,  99,  97, 108,  32,  99,  32,  61,  32, 108, 101, 116,
  116, 101, 114, 115,  91, 105, 120,  93,  10,  10,  32,  32,  32,  32,  32,  32,
   32,  32, 105, 111,  46, 119, 114, 105, 116, 101,  40,  99,  41,  10,  32,  32,
   32,  32,  32,  32,  32,  32,  99, 111, 108,  32,  61,  32,  99, 111, 108,  32,
   43,  32,  49,  10,  32,  32,  32,  32,  32,  32,  32,  32, 105, 102,  32,  99,
  111, 108,  32,  62,  61,  32,  87,  73,  68,  84,  72,  32, 116, 104, 101, 110,
   10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32, 105, 111,  46,
  119, 114, 105, 116, 101,  40,  34,  92, 110,  34,  41,  10,  32,  32,  32,  32,
   32,  32,  32,  32,  32,  32,  32,  32,  99, 111, 108,  32,  61,  32,  48,  10,
   32,  32,  32,  32,  32,  32,  32,  32, 101, 110, 100,  10,  32,  32,  32,  32,
  101, 110, 100,  10,  32,  32,  32,  32, 105, 102,  32,  99, 111, 108,  32,  62,
   32,  48,  32, 116, 104, 101, 110,  10,  32,  32,  32,  32,  32,  32,  32,  32,
  105, 111,  46, 119, 114, 105, 116, 101,  40,  34,  92, 110,  34,  41,  10,  32,
   32,  32,  32, 101, 110, 100,  10, 101, 110, 100,  10,  10, 114, 101, 116, 117,
  114, 110,  32, 123,  10,  32,  32,  32,  32, 114, 101, 112, 101,  97, 116,  95,
  102,  97, 115, 116,  97,  32,  61,  32, 114, 101, 112, 101,  97, 116,  95, 102,
   97, 115, 116,  97,  44,  10,  32,  32,  32,  32, 114,  97, 110, 100, 111, 109,
   95, 102,  97, 115, 116,  97,  32,  61,  32, 114,  97, 110, 100, 111, 109,  95,
  102,  97, 115, 116,  97,  44,  10, 125,  10,   0
#endif
};

#define LUA_AOT_LUAOPEN_NAME luaopen_benchmarks_fasta_luaot

#include "luaot_footer.c"
