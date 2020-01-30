#include "luaot_header.c"

// source = @benchmarks/mandelbrot/lua.lua
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

  // 2	[44]	CLOSURE  	0 0	; 0x1920000
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

  // 3	[46]	NEWTABLE 	1 1 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x00010091);
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

  // 4	[46]	EXTRAARG 	0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0x00000050);
    lua_assert(0);
  }

  // 5	[47]	SETFIELD 	1 0 0	; "mandelbrot"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x00000090);
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

  // 6	[48]	RETURN   	1 2 1	; 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_05 : {
    aot_vmfetch(0x010200c4);
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

  // 7	[48]	RETURN   	1 1 1	; 0 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_06 : {
    aot_vmfetch(0x010100c4);
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

// source = @benchmarks/mandelbrot/lua.lua
// lines: 1 - 44
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

  // 1	[2]	LOADI    	1 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 1)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_02
  label_00 : {
    aot_vmfetch(0x7fff8081);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 2	[3]	LOADI    	2 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x7fff8101);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 3	[5]	LOADF    	3 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x80008182);
    int b = GETARG_sBx(i);
    setfltvalue(s2v(ra), cast_num(b));
  }

  // 4	[5]	DIV      	3 3 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0x000301a5);
    op_arithf(L, luai_numdiv);
  }

  // 5	[5]	MMBIN    	3 0 11	; __div
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x0b0001ac);
    Instruction pi = 0x000301a5; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }

  // 6	[6]	LOADI    	4 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_07
  label_05 : {
    aot_vmfetch(0x7fff8201);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 7	[6]	ADDI     	5 0 -1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_08
  label_06 : {
    aot_vmfetch(0x7e000293);
    op_arithI(L, l_addi, luai_numadd, TM_ADD, GETARG_k(i));
  }

  // 8	[6]	MMBINI   	0 1 7	; __sub
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_09
  label_07 : {
    aot_vmfetch(0x0780002d);
    Instruction pi = 0x7e000293;  /* original arith. expression */
    int imm = GETARG_sB(i);
    TMS tm = (TMS)GETARG_C(i);
    int flip = GETARG_k(i);
    StkId result = RA(pi);
    Protect(luaT_trybiniTM(L, s2v(ra), imm, flip, result, tm));
  }

  // 9	[6]	LOADI    	6 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 9)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_10
  label_08 : {
    aot_vmfetch(0x80000301);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 10	[6]	FORPREP  	4 77	; to 88
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 10)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_11
  label_09 : {
    aot_vmfetch(0x00268248);
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
        goto label_88; /* skip the loop */
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
        goto label_88; /* skip the loop */
      else {
        /* make sure internal values are all float */
        setfltvalue(plimit, limit);
        setfltvalue(pstep, step);
        setfltvalue(s2v(ra), init);  /* internal index */
        setfltvalue(s2v(ra + 3), init);  /* control variable */
      }
    }
  }

  // 11	[7]	MUL      	8 7 3
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 11)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_12
  label_10 : {
    aot_vmfetch(0x03070422);
    op_arith(L, l_muli, luai_nummul);
  }

  // 12	[7]	MMBIN    	7 3 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 12)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_13
  label_11 : {
    aot_vmfetch(0x080303ac);
    Instruction pi = 0x03070422; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }

  // 13	[7]	SUBK     	8 8 0	; 1.0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 13)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_14
  label_12 : {
    aot_vmfetch(0x00080415);
    op_arithK(L, l_subi, luai_numsub, 0);
  }

  // 14	[7]	MMBINK   	8 0 7	; __sub 1.0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 14)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_15
  label_13 : {
    aot_vmfetch(0x0700042e);
    Instruction pi = 0x00080415;  /* original arith. expression */
    TValue *imm = KB(i);
    TMS tm = (TMS)GETARG_C(i);
    int flip = GETARG_k(i);
    StkId result = RA(pi);
    Protect(luaT_trybinassocTM(L, s2v(ra), imm, flip, result, tm));
  }

  // 15	[8]	LOADI    	9 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 15)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_16
  label_14 : {
    aot_vmfetch(0x7fff8481);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 16	[8]	ADDI     	10 0 -1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 16)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_17
  label_15 : {
    aot_vmfetch(0x7e000513);
    op_arithI(L, l_addi, luai_numadd, TM_ADD, GETARG_k(i));
  }

  // 17	[8]	MMBINI   	0 1 7	; __sub
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 17)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_18
  label_16 : {
    aot_vmfetch(0x0780002d);
    Instruction pi = 0x7e000513;  /* original arith. expression */
    int imm = GETARG_sB(i);
    TMS tm = (TMS)GETARG_C(i);
    int flip = GETARG_k(i);
    StkId result = RA(pi);
    Protect(luaT_trybiniTM(L, s2v(ra), imm, flip, result, tm));
  }

  // 18	[8]	LOADI    	11 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 18)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_19
  label_17 : {
    aot_vmfetch(0x80000581);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 19	[8]	FORPREP  	9 51	; to 71
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 19)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_20
  label_18 : {
    aot_vmfetch(0x001984c8);
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
        goto label_71; /* skip the loop */
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
        goto label_71; /* skip the loop */
      else {
        /* make sure internal values are all float */
        setfltvalue(plimit, limit);
        setfltvalue(pstep, step);
        setfltvalue(s2v(ra), init);  /* internal index */
        setfltvalue(s2v(ra + 3), init);  /* control variable */
      }
    }
  }

  // 20	[9]	MUL      	13 12 3
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 20)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_21
  label_19 : {
    aot_vmfetch(0x030c06a2);
    op_arith(L, l_muli, luai_nummul);
  }

  // 21	[9]	MMBIN    	12 3 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 21)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_22
  label_20 : {
    aot_vmfetch(0x0803062c);
    Instruction pi = 0x030c06a2; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }

  // 22	[9]	SUBK     	13 13 1	; 1.5
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 22)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_23
  label_21 : {
    aot_vmfetch(0x010d0695);
    op_arithK(L, l_subi, luai_numsub, 0);
  }

  // 23	[9]	MMBINK   	13 1 7	; __sub 1.5
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 23)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_24
  label_22 : {
    aot_vmfetch(0x070106ae);
    Instruction pi = 0x010d0695;  /* original arith. expression */
    TValue *imm = KB(i);
    TMS tm = (TMS)GETARG_C(i);
    int flip = GETARG_k(i);
    StkId result = RA(pi);
    Protect(luaT_trybinassocTM(L, s2v(ra), imm, flip, result, tm));
  }

  // 24	[11]	LOADI    	14 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 24)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_25
  label_23 : {
    aot_vmfetch(0x80000701);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 25	[12]	LOADF    	15 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 25)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_26
  label_24 : {
    aot_vmfetch(0x7fff8782);
    int b = GETARG_sBx(i);
    setfltvalue(s2v(ra), cast_num(b));
  }

  // 26	[13]	LOADF    	16 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 26)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_27
  label_25 : {
    aot_vmfetch(0x7fff8802);
    int b = GETARG_sBx(i);
    setfltvalue(s2v(ra), cast_num(b));
  }

  // 27	[14]	LOADF    	17 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 27)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_28
  label_26 : {
    aot_vmfetch(0x7fff8882);
    int b = GETARG_sBx(i);
    setfltvalue(s2v(ra), cast_num(b));
  }

  // 28	[15]	LOADF    	18 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 28)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_29
  label_27 : {
    aot_vmfetch(0x7fff8902);
    int b = GETARG_sBx(i);
    setfltvalue(s2v(ra), cast_num(b));
  }

  // 29	[16]	LOADI    	19 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 29)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_30
  label_28 : {
    aot_vmfetch(0x80000981);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 30	[16]	LOADI    	20 50
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 30)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_31
  label_29 : {
    aot_vmfetch(0x80188a01);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 31	[16]	LOADI    	21 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 31)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_32
  label_30 : {
    aot_vmfetch(0x80000a81);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 32	[16]	FORPREP  	19 20	; to 53
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 32)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_33
  label_31 : {
    aot_vmfetch(0x000a09c8);
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
        goto label_53; /* skip the loop */
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
        goto label_53; /* skip the loop */
      else {
        /* make sure internal values are all float */
        setfltvalue(plimit, limit);
        setfltvalue(pstep, step);
        setfltvalue(s2v(ra), init);  /* internal index */
        setfltvalue(s2v(ra + 3), init);  /* control variable */
      }
    }
  }

  // 33	[17]	MULK     	23 15 2 	; 2.0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 33)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_34
  label_32 : {
    aot_vmfetch(0x020f0b96);
    op_arithK(L, l_muli, luai_nummul, GETARG_k(i));
  }

  // 34	[17]	MMBINK   	15 2 8	; __mul 2.0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 34)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_35
  label_33 : {
    aot_vmfetch(0x080287ae);
    Instruction pi = 0x020f0b96;  /* original arith. expression */
    TValue *imm = KB(i);
    TMS tm = (TMS)GETARG_C(i);
    int flip = GETARG_k(i);
    StkId result = RA(pi);
    Protect(luaT_trybinassocTM(L, s2v(ra), imm, flip, result, tm));
  }

  // 35	[17]	MUL      	23 23 16
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 35)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_36
  label_34 : {
    aot_vmfetch(0x10170ba2);
    op_arith(L, l_muli, luai_nummul);
  }

  // 36	[17]	MMBIN    	23 16 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 36)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_37
  label_35 : {
    aot_vmfetch(0x08100bac);
    Instruction pi = 0x10170ba2; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }

  // 37	[17]	ADD      	16 23 8
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 37)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_38
  label_36 : {
    aot_vmfetch(0x08170820);
    op_arith(L, l_addi, luai_numadd);
  }

  // 38	[17]	MMBIN    	23 8 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 38)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_39
  label_37 : {
    aot_vmfetch(0x06080bac);
    Instruction pi = 0x08170820; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }

  // 39	[18]	SUB      	23 17 18
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 39)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_40
  label_38 : {
    aot_vmfetch(0x12110ba1);
    op_arith(L, l_subi, luai_numsub);
  }

  // 40	[18]	MMBIN    	17 18 7	; __sub
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 40)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_41
  label_39 : {
    aot_vmfetch(0x071208ac);
    Instruction pi = 0x12110ba1; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }

  // 41	[18]	ADD      	15 23 13
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 41)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_42
  label_40 : {
    aot_vmfetch(0x0d1707a0);
    op_arith(L, l_addi, luai_numadd);
  }

  // 42	[18]	MMBIN    	23 13 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 42)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_43
  label_41 : {
    aot_vmfetch(0x060d0bac);
    Instruction pi = 0x0d1707a0; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }

  // 43	[19]	MUL      	18 16 16
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 43)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_44
  label_42 : {
    aot_vmfetch(0x10100922);
    op_arith(L, l_muli, luai_nummul);
  }

  // 44	[19]	MMBIN    	16 16 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 44)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_45
  label_43 : {
    aot_vmfetch(0x0810082c);
    Instruction pi = 0x10100922; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }

  // 45	[20]	MUL      	17 15 15
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 45)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_46
  label_44 : {
    aot_vmfetch(0x0f0f08a2);
    op_arith(L, l_muli, luai_nummul);
  }

  // 46	[20]	MMBIN    	15 15 8	; __mul
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 46)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_47
  label_45 : {
    aot_vmfetch(0x080f07ac);
    Instruction pi = 0x0f0f08a2; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }

  // 47	[21]	ADD      	23 18 17
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 47)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_48
  label_46 : {
    aot_vmfetch(0x11120ba0);
    op_arith(L, l_addi, luai_numadd);
  }

  // 48	[21]	MMBIN    	18 17 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 48)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_49
  label_47 : {
    aot_vmfetch(0x0611092c);
    Instruction pi = 0x11120ba0; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }

  // 49	[21]	GTI      	23 4 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 49)
  #undef  LUA_AOT_NEXT_JUMP
  #define LUA_AOT_NEXT_JUMP label_52
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_50
  label_48 : {
    aot_vmfetch(0x01830bbe);
    op_orderI(L, l_gti, luai_numgt, 1, TM_LT);
  }

  // 50	[21]	JMP      	2	; to 53
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 50)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_51
  label_49 : {
    aot_vmfetch(0x800000b6);
    updatetrap(ci);
    goto label_52;
  }

  // 51	[22]	LOADI    	14 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 51)
  #undef  LUA_AOT_NEXT_JUMP
  #define LUA_AOT_NEXT_JUMP label_53
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_52
  label_50 : {
    aot_vmfetch(0x7fff8701);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 52	[23]	JMP      	1	; to 54
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 52)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_53
  label_51 : {
    aot_vmfetch(0x80000036);
    updatetrap(ci);
    goto label_53;
  }

  // 53	[16]	FORLOOP  	19 21	; to 33
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 53)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_54
  label_52 : {
    aot_vmfetch(0x000a89c7);
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

  // 54	[27]	SHRI     	19 1 -1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 54)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_55
  label_53 : {
    aot_vmfetch(0x7e01099e);
    TValue *rb = vRB(i);
    int ic = GETARG_sC(i);
    lua_Integer ib;
    if (tointegerns(rb, &ib)) {
       setivalue(s2v(ra), luaV_shiftl(ib, -ic));
       goto LUA_AOT_SKIP1;
    }
  }

  // 55	[27]	MMBINI   	1 1 16	; __shl
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 55)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_56
  label_54 : {
    aot_vmfetch(0x108000ad);
    Instruction pi = 0x7e01099e;  /* original arith. expression */
    int imm = GETARG_sB(i);
    TMS tm = (TMS)GETARG_C(i);
    int flip = GETARG_k(i);
    StkId result = RA(pi);
    Protect(luaT_trybiniTM(L, s2v(ra), imm, flip, result, tm));
  }

  // 56	[27]	BOR      	1 19 14
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 56)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_57
  label_55 : {
    aot_vmfetch(0x0e1300a8);
    op_bitwise(L, l_bor);
  }

  // 57	[27]	MMBIN    	19 14 14	; __bor
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 57)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_58
  label_56 : {
    aot_vmfetch(0x0e0e09ac);
    Instruction pi = 0x0e1300a8; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }

  // 58	[28]	ADDI     	2 2 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 58)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_59
  label_57 : {
    aot_vmfetch(0x80020113);
    op_arithI(L, l_addi, luai_numadd, TM_ADD, GETARG_k(i));
  }

  // 59	[28]	MMBINI   	2 1 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 59)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_60
  label_58 : {
    aot_vmfetch(0x0680012d);
    Instruction pi = 0x80020113;  /* original arith. expression */
    int imm = GETARG_sB(i);
    TMS tm = (TMS)GETARG_C(i);
    int flip = GETARG_k(i);
    StkId result = RA(pi);
    Protect(luaT_trybiniTM(L, s2v(ra), imm, flip, result, tm));
  }

  // 60	[30]	EQI      	2 8 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 60)
  #undef  LUA_AOT_NEXT_JUMP
  #define LUA_AOT_NEXT_JUMP label_70
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_61
  label_59 : {
    aot_vmfetch(0x0087013b);
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

  // 61	[30]	JMP      	9	; to 71
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 61)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_62
  label_60 : {
    aot_vmfetch(0x80000436);
    updatetrap(ci);
    goto label_70;
  }

  // 62	[31]	GETTABUP 	19 0 3	; _ENV "io"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 62)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_63
  label_61 : {
    aot_vmfetch(0x03000989);
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

  // 63	[31]	GETFIELD 	19 19 4	; "write"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 63)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_64
  label_62 : {
    aot_vmfetch(0x0413098c);
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

  // 64	[31]	GETTABUP 	20 0 5	; _ENV "string"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 64)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_65
  label_63 : {
    aot_vmfetch(0x05000a09);
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

  // 65	[31]	GETFIELD 	20 20 6	; "char"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 65)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_66
  label_64 : {
    aot_vmfetch(0x06140a0c);
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

  // 66	[31]	MOVE     	21 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 66)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_67
  label_65 : {
    aot_vmfetch(0x00010a80);
    setobjs2s(L, ra, RB(i));
  }

  // 67	[31]	CALL     	20 2 0	; 1 in all out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 67)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_68
  label_66 : {
    aot_vmfetch(0x00020a42);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }

  // 68	[31]	CALL     	19 0 1	; all in 0 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 68)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_69
  label_67 : {
    aot_vmfetch(0x010009c2);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }

  // 69	[32]	LOADI    	1 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 69)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_70
  label_68 : {
    aot_vmfetch(0x7fff8081);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 70	[33]	LOADI    	2 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 70)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_71
  label_69 : {
    aot_vmfetch(0x7fff8101);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 71	[8]	FORLOOP  	9 52	; to 20
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 71)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_72
  label_70 : {
    aot_vmfetch(0x001a04c7);
    if (ttisinteger(s2v(ra + 2))) {  /* integer loop? */
      lua_Unsigned count = l_castS2U(ivalue(s2v(ra + 1)));
      if (count > 0) {  /* still more iterations? */
        lua_Integer step = ivalue(s2v(ra + 2));
        lua_Integer idx = ivalue(s2v(ra));  /* internal index */
        chgivalue(s2v(ra + 1), count - 1);  /* update counter */
        idx = intop(+, idx, step);  /* add step to index */
        chgivalue(s2v(ra), idx);  /* update internal index */
        setivalue(s2v(ra + 3), idx);  /* and control variable */
        goto label_19; /* jump back */
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
        goto label_19; /* jump back */
      }
    }
    updatetrap(ci);  /* allows a signal to break the loop */
  }

  // 72	[37]	GTI      	2 0 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 72)
  #undef  LUA_AOT_NEXT_JUMP
  #define LUA_AOT_NEXT_JUMP label_87
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_73
  label_71 : {
    aot_vmfetch(0x007f013e);
    op_orderI(L, l_gti, luai_numgt, 1, TM_LT);
  }

  // 73	[37]	JMP      	14	; to 88
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 73)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_74
  label_72 : {
    aot_vmfetch(0x800006b6);
    updatetrap(ci);
    goto label_87;
  }

  // 74	[38]	LOADI    	9 8
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 74)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_75
  label_73 : {
    aot_vmfetch(0x80038481);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 75	[38]	SUB      	9 9 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 75)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_76
  label_74 : {
    aot_vmfetch(0x020904a1);
    op_arith(L, l_subi, luai_numsub);
  }

  // 76	[38]	MMBIN    	9 2 7	; __sub
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 76)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_77
  label_75 : {
    aot_vmfetch(0x070204ac);
    Instruction pi = 0x020904a1; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }

  // 77	[38]	SHL      	1 1 9
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 77)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_78
  label_76 : {
    aot_vmfetch(0x090100aa);
    op_bitwise(L, luaV_shiftl);
  }

  // 78	[38]	MMBIN    	1 9 16	; __shl
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 78)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_79
  label_77 : {
    aot_vmfetch(0x100900ac);
    Instruction pi = 0x090100aa; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }

  // 79	[39]	GETTABUP 	9 0 3	; _ENV "io"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 79)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_80
  label_78 : {
    aot_vmfetch(0x03000489);
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

  // 80	[39]	GETFIELD 	9 9 4	; "write"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 80)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_81
  label_79 : {
    aot_vmfetch(0x0409048c);
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

  // 81	[39]	GETTABUP 	10 0 5	; _ENV "string"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 81)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_82
  label_80 : {
    aot_vmfetch(0x05000509);
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

  // 82	[39]	GETFIELD 	10 10 6	; "char"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 82)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_83
  label_81 : {
    aot_vmfetch(0x060a050c);
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

  // 83	[39]	MOVE     	11 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 83)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_84
  label_82 : {
    aot_vmfetch(0x00010580);
    setobjs2s(L, ra, RB(i));
  }

  // 84	[39]	CALL     	10 2 0	; 1 in all out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 84)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_85
  label_83 : {
    aot_vmfetch(0x00020542);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }

  // 85	[39]	CALL     	9 0 1	; all in 0 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 85)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_86
  label_84 : {
    aot_vmfetch(0x010004c2);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }

  // 86	[40]	LOADI    	1 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 86)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_87
  label_85 : {
    aot_vmfetch(0x7fff8081);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 87	[41]	LOADI    	2 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 87)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_88
  label_86 : {
    aot_vmfetch(0x7fff8101);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 88	[6]	FORLOOP  	4 78	; to 11
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 88)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_87 : {
    aot_vmfetch(0x00270247);
    if (ttisinteger(s2v(ra + 2))) {  /* integer loop? */
      lua_Unsigned count = l_castS2U(ivalue(s2v(ra + 1)));
      if (count > 0) {  /* still more iterations? */
        lua_Integer step = ivalue(s2v(ra + 2));
        lua_Integer idx = ivalue(s2v(ra));  /* internal index */
        chgivalue(s2v(ra + 1), count - 1);  /* update counter */
        idx = intop(+, idx, step);  /* add step to index */
        chgivalue(s2v(ra), idx);  /* update internal index */
        setivalue(s2v(ra + 3), idx);  /* and control variable */
        goto label_10; /* jump back */
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
        goto label_10; /* jump back */
      }
    }
    updatetrap(ci);  /* allows a signal to break the loop */
  }

  // 89	[44]	RETURN0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 89)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_88 : {
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

static AotCompiledFunction LUA_AOT_FUNCTIONS[] = {
  magic_implementation_00,
  magic_implementation_01,
  NULL
};

static const char LUA_AOT_MODULE_SOURCE_CODE[] = {
#if 0
  108, 111,  99,  97, 108,  32, 102, 117, 110,  99, 116, 105, 111, 110,  32, 109,
   97, 110, 100, 101, 108,  98, 114, 111, 116,  40,  78,  41,  10,  32,  32,  32,
   32, 108, 111,  99,  97, 108,  32,  98, 105, 116, 115,  32,  32,  61,  32,  48,
   10,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32, 110,  98, 105, 116, 115,
   32,  61,  32,  48,  10,  10,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32,
  100, 101, 108, 116,  97,  32,  61,  32,  50,  46,  48,  32,  47,  32,  78,  10,
   32,  32,  32,  32, 102, 111, 114,  32, 121,  32,  61,  32,  48,  44,  32,  78,
   45,  49,  32, 100, 111,  10,  32,  32,  32,  32,  32,  32,  32,  32, 108, 111,
   99,  97, 108,  32,  67, 105,  32,  61,  32, 121,  42, 100, 101, 108, 116,  97,
   32,  45,  32,  49,  46,  48,  10,  32,  32,  32,  32,  32,  32,  32,  32, 102,
  111, 114,  32, 120,  32,  61,  32,  48,  44,  32,  78,  45,  49,  32, 100, 111,
   10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32, 108, 111,  99,
   97, 108,  32,  67, 114,  32,  61,  32, 120,  42, 100, 101, 108, 116,  97,  32,
   45,  32,  49,  46,  53,  10,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,
   32,  32,  32, 108, 111,  99,  97, 108,  32,  98, 105, 116,  32,  61,  32,  48,
  120,  49,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32, 108,
  111,  99,  97, 108,  32,  90, 114,  32,  32,  61,  32,  48,  46,  48,  10,  32,
   32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32, 108, 111,  99,  97, 108,
   32,  90, 105,  32,  32,  61,  32,  48,  46,  48,  10,  32,  32,  32,  32,  32,
   32,  32,  32,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32,  90, 114,  50,
   32,  61,  32,  48,  46,  48,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,
   32,  32,  32, 108, 111,  99,  97, 108,  32,  90, 105,  50,  32,  61,  32,  48,
   46,  48,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32, 102,
  111, 114,  32,  95,  32,  61,  32,  49,  44,  32,  53,  48,  32, 100, 111,  10,
   32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,
   90, 105,  32,  61,  32,  50,  46,  48,  32,  42,  32,  90, 114,  32,  42,  32,
   90, 105,  32,  43,  32,  67, 105,  10,  32,  32,  32,  32,  32,  32,  32,  32,
   32,  32,  32,  32,  32,  32,  32,  32,  90, 114,  32,  61,  32,  90, 114,  50,
   32,  45,  32,  90, 105,  50,  32,  43,  32,  67, 114,  10,  32,  32,  32,  32,
   32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  90, 105,  50,  32,
   61,  32,  90, 105,  32,  42,  32,  90, 105,  10,  32,  32,  32,  32,  32,  32,
   32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  90, 114,  50,  32,  61,  32,
   90, 114,  32,  42,  32,  90, 114,  10,  32,  32,  32,  32,  32,  32,  32,  32,
   32,  32,  32,  32,  32,  32,  32,  32, 105, 102,  32,  90, 105,  50,  32,  43,
   32,  90, 114,  50,  32,  62,  32,  52,  46,  48,  32, 116, 104, 101, 110,  10,
   32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,
   32,  32,  32,  32,  98, 105, 116,  32,  61,  32,  48, 120,  48,  10,  32,  32,
   32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,
   32,  32,  98, 114, 101,  97, 107,  10,  32,  32,  32,  32,  32,  32,  32,  32,
   32,  32,  32,  32,  32,  32,  32,  32, 101, 110, 100,  10,  32,  32,  32,  32,
   32,  32,  32,  32,  32,  32,  32,  32, 101, 110, 100,  10,  10,  32,  32,  32,
   32,  32,  32,  32,  32,  32,  32,  32,  32,  98, 105, 116, 115,  32,  61,  32,
   40,  98, 105, 116, 115,  32,  60,  60,  32,  49,  41,  32, 124,  32,  98, 105,
  116,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32, 110,  98,
  105, 116, 115,  32,  61,  32, 110,  98, 105, 116, 115,  32,  43,  32,  49,  10,
   10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32, 105, 102,  32,
  110,  98, 105, 116, 115,  32,  61,  61,  32,  56,  32, 116, 104, 101, 110,  10,
   32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,
  105, 111,  46, 119, 114, 105, 116, 101,  40, 115, 116, 114, 105, 110, 103,  46,
   99, 104,  97, 114,  40,  98, 105, 116, 115,  41,  41,  10,  32,  32,  32,  32,
   32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  98, 105, 116, 115,
   32,  32,  61,  32,  48,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,
   32,  32,  32,  32,  32,  32, 110,  98, 105, 116, 115,  32,  61,  32,  48,  10,
   32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32, 101, 110, 100,  10,
   32,  32,  32,  32,  32,  32,  32,  32, 101, 110, 100,  10,  10,  32,  32,  32,
   32,  32,  32,  32,  32, 105, 102,  32, 110,  98, 105, 116, 115,  32,  62,  32,
   48,  32, 116, 104, 101, 110,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,
   32,  32,  32,  98, 105, 116, 115,  32,  32,  61,  32,  98, 105, 116, 115,  32,
   60,  60,  32,  40,  56,  32,  45,  32, 110,  98, 105, 116, 115,  41,  10,  32,
   32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32, 105, 111,  46, 119, 114,
  105, 116, 101,  40, 115, 116, 114, 105, 110, 103,  46,  99, 104,  97, 114,  40,
   98, 105, 116, 115,  41,  41,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,
   32,  32,  32,  98, 105, 116, 115,  32,  32,  61,  32,  48,  10,  32,  32,  32,
   32,  32,  32,  32,  32,  32,  32,  32,  32, 110,  98, 105, 116, 115,  32,  61,
   32,  48,  10,  32,  32,  32,  32,  32,  32,  32,  32, 101, 110, 100,  10,  32,
   32,  32,  32, 101, 110, 100,  10, 101, 110, 100,  10,  10, 114, 101, 116, 117,
  114, 110,  32, 123,  10,  32,  32,  32,  32, 109,  97, 110, 100, 101, 108,  98,
  114, 111, 116,  32,  61,  32, 109,  97, 110, 100, 101, 108,  98, 114, 111, 116,
   10, 125,  10,   0
#endif
};

#define LUA_AOT_LUAOPEN_NAME luaopen_benchmarks_mandelbrot_luaot

#include "luaot_footer.c"
