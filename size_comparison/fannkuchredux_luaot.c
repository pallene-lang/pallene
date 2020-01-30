#include "luaot_header.c"

// source = @benchmarks/fannkuchredux/lua.lua
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

  // 2	[81]	CLOSURE  	0 0	; 0x1644010
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

  // 3	[83]	NEWTABLE 	1 1 0
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

  // 4	[83]	EXTRAARG 	0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0x00000050);
    lua_assert(0);
  }

  // 5	[84]	SETFIELD 	1 0 0	; "fannkuch"
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

  // 6	[85]	RETURN   	1 2 1	; 1 out
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

  // 7	[85]	RETURN   	1 1 1	; 0 out
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

// source = @benchmarks/fannkuchredux/lua.lua
// lines: 1 - 81
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

  // 1	[3]	NEWTABLE 	1 0 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 1)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_02
  label_00 : {
    aot_vmfetch(0x00000091);
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

  // 2	[3]	EXTRAARG 	0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x00000050);
    lua_assert(0);
  }

  // 3	[4]	LOADI    	2 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x80000101);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 4	[4]	MOVE     	3 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0x00000180);
    setobjs2s(L, ra, RB(i));
  }

  // 5	[4]	LOADI    	4 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x80000201);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 6	[4]	FORPREP  	2 1	; to 8
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_07
  label_05 : {
    aot_vmfetch(0x00008148);
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
        goto label_08; /* skip the loop */
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
        goto label_08; /* skip the loop */
      else {
        /* make sure internal values are all float */
        setfltvalue(plimit, limit);
        setfltvalue(pstep, step);
        setfltvalue(s2v(ra), init);  /* internal index */
        setfltvalue(s2v(ra + 3), init);  /* control variable */
      }
    }
  }

  // 7	[5]	SETTABLE 	1 5 5
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_08
  label_06 : {
    aot_vmfetch(0x0505008e);
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

  // 8	[4]	FORLOOP  	2 2	; to 7
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_09
  label_07 : {
    aot_vmfetch(0x00010147);
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

  // 9	[8]	NEWTABLE 	2 0 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 9)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_10
  label_08 : {
    aot_vmfetch(0x00000111);
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

  // 10	[8]	EXTRAARG 	0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 10)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_11
  label_09 : {
    aot_vmfetch(0x00000050);
    lua_assert(0);
  }

  // 11	[10]	NEWTABLE 	3 0 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 11)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_12
  label_10 : {
    aot_vmfetch(0x00000191);
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

  // 12	[10]	EXTRAARG 	0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 12)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_13
  label_11 : {
    aot_vmfetch(0x00000050);
    lua_assert(0);
  }

  // 13	[11]	SETI     	3 1 0k	; 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 13)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_14
  label_12 : {
    aot_vmfetch(0x0001818f);
    const TValue *slot;
    int c = GETARG_B(i);
    TValue *rc = RKC(i);
    if (luaV_fastgeti(L, s2v(ra), c, slot)) {
      luaV_finishfastset(L, s2v(ra), slot, rc);
    }
    else {
      TValue key;
      setivalue(&key, c);
      Protect(luaV_finishset(L, s2v(ra), &key, rc, slot));
    }
  }

  // 14	[12]	MOVE     	4 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 14)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_15
  label_13 : {
    aot_vmfetch(0x00000200);
    setobjs2s(L, ra, RB(i));
  }

  // 15	[14]	LOADI    	5 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 15)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_16
  label_14 : {
    aot_vmfetch(0x7fff8281);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 16	[15]	LOADI    	6 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 16)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_17
  label_15 : {
    aot_vmfetch(0x7fff8301);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 17	[16]	LOADI    	7 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 17)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_18
  label_16 : {
    aot_vmfetch(0x7fff8381);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 18	[23]	LOADI    	8 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 18)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_19
  label_17 : {
    aot_vmfetch(0x80000401);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 19	[23]	MOVE     	9 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 19)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_20
  label_18 : {
    aot_vmfetch(0x00000480);
    setobjs2s(L, ra, RB(i));
  }

  // 20	[23]	LOADI    	10 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 20)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_21
  label_19 : {
    aot_vmfetch(0x80000501);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 21	[23]	FORPREP  	8 2	; to 24
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 21)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_22
  label_20 : {
    aot_vmfetch(0x00010448);
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
        goto label_24; /* skip the loop */
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
        goto label_24; /* skip the loop */
      else {
        /* make sure internal values are all float */
        setfltvalue(plimit, limit);
        setfltvalue(pstep, step);
        setfltvalue(s2v(ra), init);  /* internal index */
        setfltvalue(s2v(ra + 3), init);  /* control variable */
      }
    }
  }

  // 22	[24]	GETTABLE 	12 1 11
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 22)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_23
  label_21 : {
    aot_vmfetch(0x0b01060a);
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

  // 23	[24]	SETTABLE 	2 11 12
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 23)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_24
  label_22 : {
    aot_vmfetch(0x0c0b010e);
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

  // 24	[23]	FORLOOP  	8 3	; to 22
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 24)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_25
  label_23 : {
    aot_vmfetch(0x00018447);
    if (ttisinteger(s2v(ra + 2))) {  /* integer loop? */
      lua_Unsigned count = l_castS2U(ivalue(s2v(ra + 1)));
      if (count > 0) {  /* still more iterations? */
        lua_Integer step = ivalue(s2v(ra + 2));
        lua_Integer idx = ivalue(s2v(ra));  /* internal index */
        chgivalue(s2v(ra + 1), count - 1);  /* update counter */
        idx = intop(+, idx, step);  /* add step to index */
        chgivalue(s2v(ra), idx);  /* update internal index */
        setivalue(s2v(ra + 3), idx);  /* and control variable */
        goto label_21; /* jump back */
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
        goto label_21; /* jump back */
      }
    }
    updatetrap(ci);  /* allows a signal to break the loop */
  }

  // 25	[27]	LOADI    	8 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 25)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_26
  label_24 : {
    aot_vmfetch(0x7fff8401);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 26	[28]	GETI     	9 2 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 26)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_27
  label_25 : {
    aot_vmfetch(0x0102048b);
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

  // 27	[29]	GTI      	9 1 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 27)
  #undef  LUA_AOT_NEXT_JUMP
  #define LUA_AOT_NEXT_JUMP label_44
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_28
  label_26 : {
    aot_vmfetch(0x008004be);
    op_orderI(L, l_gti, luai_numgt, 1, TM_LT);
  }

  // 28	[29]	JMP      	16	; to 45
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 28)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_29
  label_27 : {
    aot_vmfetch(0x800007b6);
    updatetrap(ci);
    goto label_44;
  }

  // 29	[30]	LOADI    	10 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 29)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_30
  label_28 : {
    aot_vmfetch(0x80000501);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 30	[31]	MOVE     	11 9
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 30)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_31
  label_29 : {
    aot_vmfetch(0x00090580);
    setobjs2s(L, ra, RB(i));
  }

  // 31	[33]	GETTABLE 	12 2 10
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 31)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_32
  label_30 : {
    aot_vmfetch(0x0a02060a);
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

  // 32	[34]	GETTABLE 	13 2 11
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 32)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_33
  label_31 : {
    aot_vmfetch(0x0b02068a);
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

  // 33	[35]	SETTABLE 	2 10 13
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 33)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_34
  label_32 : {
    aot_vmfetch(0x0d0a010e);
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

  // 34	[36]	SETTABLE 	2 11 12
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 34)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_35
  label_33 : {
    aot_vmfetch(0x0c0b010e);
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

  // 35	[37]	ADDI     	10 10 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 35)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_36
  label_34 : {
    aot_vmfetch(0x800a0513);
    op_arithI(L, l_addi, luai_numadd, TM_ADD, GETARG_k(i));
  }

  // 36	[37]	MMBINI   	10 1 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 36)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_37
  label_35 : {
    aot_vmfetch(0x0680052d);
    Instruction pi = 0x800a0513;  /* original arith. expression */
    int imm = GETARG_sB(i);
    TMS tm = (TMS)GETARG_C(i);
    int flip = GETARG_k(i);
    StkId result = RA(pi);
    Protect(luaT_trybiniTM(L, s2v(ra), imm, flip, result, tm));
  }

  // 37	[38]	ADDI     	11 11 -1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 37)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_38
  label_36 : {
    aot_vmfetch(0x7e0b0593);
    op_arithI(L, l_addi, luai_numadd, TM_ADD, GETARG_k(i));
  }

  // 38	[38]	MMBINI   	11 1 7	; __sub
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 38)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_39
  label_37 : {
    aot_vmfetch(0x078005ad);
    Instruction pi = 0x7e0b0593;  /* original arith. expression */
    int imm = GETARG_sB(i);
    TMS tm = (TMS)GETARG_C(i);
    int flip = GETARG_k(i);
    StkId result = RA(pi);
    Protect(luaT_trybiniTM(L, s2v(ra), imm, flip, result, tm));
  }

  // 39	[39]	LE       	11 10 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 39)
  #undef  LUA_AOT_NEXT_JUMP
  #define LUA_AOT_NEXT_JUMP label_30
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_40
  label_38 : {
    aot_vmfetch(0x000a05b9);
    op_order(L, l_lei, LEnum, lessequalothers);
  }

  // 40	[39]	JMP      	-10	; to 31
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 40)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_41
  label_39 : {
    aot_vmfetch(0x7ffffab6);
    updatetrap(ci);
    goto label_30;
  }

  // 41	[41]	ADDI     	8 8 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 41)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_42
  label_40 : {
    aot_vmfetch(0x80080413);
    op_arithI(L, l_addi, luai_numadd, TM_ADD, GETARG_k(i));
  }

  // 42	[41]	MMBINI   	8 1 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 42)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_43
  label_41 : {
    aot_vmfetch(0x0680042d);
    Instruction pi = 0x80080413;  /* original arith. expression */
    int imm = GETARG_sB(i);
    TMS tm = (TMS)GETARG_C(i);
    int flip = GETARG_k(i);
    StkId result = RA(pi);
    Protect(luaT_trybiniTM(L, s2v(ra), imm, flip, result, tm));
  }

  // 43	[42]	GETI     	9 2 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 43)
  #undef  LUA_AOT_NEXT_JUMP
  #define LUA_AOT_NEXT_JUMP label_26
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_44
  label_42 : {
    aot_vmfetch(0x0102048b);
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

  // 44	[42]	JMP      	-18	; to 27
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 44)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_45
  label_43 : {
    aot_vmfetch(0x7ffff6b6);
    updatetrap(ci);
    goto label_26;
  }

  // 45	[45]	LT       	6 8 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 45)
  #undef  LUA_AOT_NEXT_JUMP
  #define LUA_AOT_NEXT_JUMP label_47
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_46
  label_44 : {
    aot_vmfetch(0x00080338);
    op_order(L, l_lti, LTnum, lessthanothers);
  }

  // 46	[45]	JMP      	1	; to 48
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 46)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_47
  label_45 : {
    aot_vmfetch(0x80000036);
    updatetrap(ci);
    goto label_47;
  }

  // 47	[46]	MOVE     	6 8
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 47)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_48
  label_46 : {
    aot_vmfetch(0x00080300);
    setobjs2s(L, ra, RB(i));
  }

  // 48	[49]	MODK     	10 5 1	; 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 48)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_49
  label_47 : {
    aot_vmfetch(0x01050517);
    op_arithK(L, luaV_mod, luaV_modf, 0);
  }

  // 49	[49]	MMBINK   	5 1 9	; __mod 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 49)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_50
  label_48 : {
    aot_vmfetch(0x090102ae);
    Instruction pi = 0x01050517;  /* original arith. expression */
    TValue *imm = KB(i);
    TMS tm = (TMS)GETARG_C(i);
    int flip = GETARG_k(i);
    StkId result = RA(pi);
    Protect(luaT_trybinassocTM(L, s2v(ra), imm, flip, result, tm));
  }

  // 50	[49]	EQI      	10 0 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 50)
  #undef  LUA_AOT_NEXT_JUMP
  #define LUA_AOT_NEXT_JUMP label_54
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_51
  label_49 : {
    aot_vmfetch(0x007f053b);
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

  // 51	[49]	JMP      	3	; to 55
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 51)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_52
  label_50 : {
    aot_vmfetch(0x80000136);
    updatetrap(ci);
    goto label_54;
  }

  // 52	[50]	ADD      	7 7 8
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 52)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_53
  label_51 : {
    aot_vmfetch(0x080703a0);
    op_arith(L, l_addi, luai_numadd);
  }

  // 53	[50]	MMBIN    	7 8 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 53)
  #undef  LUA_AOT_NEXT_JUMP
  #define LUA_AOT_NEXT_JUMP label_56
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_54
  label_52 : {
    aot_vmfetch(0x060803ac);
    Instruction pi = 0x080703a0; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }

  // 54	[50]	JMP      	2	; to 57
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 54)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_55
  label_53 : {
    aot_vmfetch(0x800000b6);
    updatetrap(ci);
    goto label_56;
  }

  // 55	[52]	SUB      	7 7 8
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 55)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_56
  label_54 : {
    aot_vmfetch(0x080703a1);
    op_arith(L, l_subi, luai_numsub);
  }

  // 56	[52]	MMBIN    	7 8 7	; __sub
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 56)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_57
  label_55 : {
    aot_vmfetch(0x070803ac);
    Instruction pi = 0x080703a1; /* original arith. expression */
    TValue *rb = vRB(i);
    TMS tm = (TMS)GETARG_C(i);
    StkId result = RA(pi);
    lua_assert(OP_ADD <= GET_OPCODE(pi) && GET_OPCODE(pi) <= OP_SHR);
    Protect(luaT_trybinTM(L, s2v(ra), rb, result, tm));
  }

  // 57	[58]	GTI      	4 1 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 57)
  #undef  LUA_AOT_NEXT_JUMP
  #define LUA_AOT_NEXT_JUMP label_62
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_58
  label_56 : {
    aot_vmfetch(0x0080023e);
    op_orderI(L, l_gti, luai_numgt, 1, TM_LT);
  }

  // 58	[58]	JMP      	4	; to 63
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 58)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_59
  label_57 : {
    aot_vmfetch(0x800001b6);
    updatetrap(ci);
    goto label_62;
  }

  // 59	[59]	SETTABLE 	3 4 4
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 59)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_60
  label_58 : {
    aot_vmfetch(0x0404018e);
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

  // 60	[60]	ADDI     	4 4 -1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 60)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_61
  label_59 : {
    aot_vmfetch(0x7e040213);
    op_arithI(L, l_addi, luai_numadd, TM_ADD, GETARG_k(i));
  }

  // 61	[60]	MMBINI   	4 1 7	; __sub
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 61)
  #undef  LUA_AOT_NEXT_JUMP
  #define LUA_AOT_NEXT_JUMP label_56
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_62
  label_60 : {
    aot_vmfetch(0x0780022d);
    Instruction pi = 0x7e040213;  /* original arith. expression */
    int imm = GETARG_sB(i);
    TMS tm = (TMS)GETARG_C(i);
    int flip = GETARG_k(i);
    StkId result = RA(pi);
    Protect(luaT_trybiniTM(L, s2v(ra), imm, flip, result, tm));
  }

  // 62	[60]	JMP      	-6	; to 57
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 62)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_63
  label_61 : {
    aot_vmfetch(0x7ffffcb6);
    updatetrap(ci);
    goto label_56;
  }

  // 63	[64]	EQ       	4 0 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 63)
  #undef  LUA_AOT_NEXT_JUMP
  #define LUA_AOT_NEXT_JUMP label_70
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_64
  label_62 : {
    aot_vmfetch(0x00000237);
    int cond;
    TValue *rb = vRB(i);
    Protect(cond = luaV_equalobj(L, s2v(ra), rb));
    docondjump();
  }

  // 64	[64]	JMP      	6	; to 71
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 64)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_65
  label_63 : {
    aot_vmfetch(0x800002b6);
    updatetrap(ci);
    goto label_70;
  }

  // 65	[65]	NEWTABLE 	8 0 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 65)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_66
  label_64 : {
    aot_vmfetch(0x02000411);
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

  // 66	[65]	EXTRAARG 	0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 66)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_67
  label_65 : {
    aot_vmfetch(0x00000050);
    lua_assert(0);
  }

  // 67	[65]	MOVE     	9 7
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 67)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_68
  label_66 : {
    aot_vmfetch(0x00070480);
    setobjs2s(L, ra, RB(i));
  }

  // 68	[65]	MOVE     	10 6
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 68)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_69
  label_67 : {
    aot_vmfetch(0x00060500);
    setobjs2s(L, ra, RB(i));
  }

  // 69	[65]	SETLIST  	8 2 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 69)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_70
  label_68 : {
    aot_vmfetch(0x0002044c);
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
          last += GETARG_Ax(0x00020446) * (MAXARG_C + 1);
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

  // 70	[65]	RETURN1  	8
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 70)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_71
  label_69 : {
    aot_vmfetch(0x00020446);
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

  // 71	[68]	GETI     	8 1 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 71)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_72
  label_70 : {
    aot_vmfetch(0x0101040b);
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

  // 72	[69]	LOADI    	9 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 72)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_73
  label_71 : {
    aot_vmfetch(0x80000481);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 73	[69]	MOVE     	10 4
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 73)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_74
  label_72 : {
    aot_vmfetch(0x00040500);
    setobjs2s(L, ra, RB(i));
  }

  // 74	[69]	LOADI    	11 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 74)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_75
  label_73 : {
    aot_vmfetch(0x80000581);
    lua_Integer b = GETARG_sBx(i);
    setivalue(s2v(ra), b);
  }

  // 75	[69]	FORPREP  	9 4	; to 80
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 75)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_76
  label_74 : {
    aot_vmfetch(0x000204c8);
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
        goto label_80; /* skip the loop */
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
        goto label_80; /* skip the loop */
      else {
        /* make sure internal values are all float */
        setfltvalue(plimit, limit);
        setfltvalue(pstep, step);
        setfltvalue(s2v(ra), init);  /* internal index */
        setfltvalue(s2v(ra + 3), init);  /* control variable */
      }
    }
  }

  // 76	[70]	ADDI     	13 12 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 76)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_77
  label_75 : {
    aot_vmfetch(0x800c0693);
    op_arithI(L, l_addi, luai_numadd, TM_ADD, GETARG_k(i));
  }

  // 77	[70]	MMBINI   	12 1 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 77)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_78
  label_76 : {
    aot_vmfetch(0x0680062d);
    Instruction pi = 0x800c0693;  /* original arith. expression */
    int imm = GETARG_sB(i);
    TMS tm = (TMS)GETARG_C(i);
    int flip = GETARG_k(i);
    StkId result = RA(pi);
    Protect(luaT_trybiniTM(L, s2v(ra), imm, flip, result, tm));
  }

  // 78	[70]	GETTABLE 	13 1 13
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 78)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_79
  label_77 : {
    aot_vmfetch(0x0d01068a);
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

  // 79	[70]	SETTABLE 	1 12 13
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 79)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_80
  label_78 : {
    aot_vmfetch(0x0d0c008e);
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

  // 80	[69]	FORLOOP  	9 5	; to 76
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 80)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_81
  label_79 : {
    aot_vmfetch(0x000284c7);
    if (ttisinteger(s2v(ra + 2))) {  /* integer loop? */
      lua_Unsigned count = l_castS2U(ivalue(s2v(ra + 1)));
      if (count > 0) {  /* still more iterations? */
        lua_Integer step = ivalue(s2v(ra + 2));
        lua_Integer idx = ivalue(s2v(ra));  /* internal index */
        chgivalue(s2v(ra + 1), count - 1);  /* update counter */
        idx = intop(+, idx, step);  /* add step to index */
        chgivalue(s2v(ra), idx);  /* update internal index */
        setivalue(s2v(ra + 3), idx);  /* and control variable */
        goto label_75; /* jump back */
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
        goto label_75; /* jump back */
      }
    }
    updatetrap(ci);  /* allows a signal to break the loop */
  }

  // 81	[72]	ADDI     	9 4 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 81)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_82
  label_80 : {
    aot_vmfetch(0x80040493);
    op_arithI(L, l_addi, luai_numadd, TM_ADD, GETARG_k(i));
  }

  // 82	[72]	MMBINI   	4 1 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 82)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_83
  label_81 : {
    aot_vmfetch(0x0680022d);
    Instruction pi = 0x80040493;  /* original arith. expression */
    int imm = GETARG_sB(i);
    TMS tm = (TMS)GETARG_C(i);
    int flip = GETARG_k(i);
    StkId result = RA(pi);
    Protect(luaT_trybiniTM(L, s2v(ra), imm, flip, result, tm));
  }

  // 83	[72]	SETTABLE 	1 9 8
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 83)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_84
  label_82 : {
    aot_vmfetch(0x0809008e);
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

  // 84	[74]	ADDI     	9 4 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 84)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_85
  label_83 : {
    aot_vmfetch(0x80040493);
    op_arithI(L, l_addi, luai_numadd, TM_ADD, GETARG_k(i));
  }

  // 85	[74]	MMBINI   	4 1 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 85)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_86
  label_84 : {
    aot_vmfetch(0x0680022d);
    Instruction pi = 0x80040493;  /* original arith. expression */
    int imm = GETARG_sB(i);
    TMS tm = (TMS)GETARG_C(i);
    int flip = GETARG_k(i);
    StkId result = RA(pi);
    Protect(luaT_trybiniTM(L, s2v(ra), imm, flip, result, tm));
  }

  // 86	[75]	GETTABLE 	10 3 9
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 86)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_87
  label_85 : {
    aot_vmfetch(0x0903050a);
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

  // 87	[75]	ADDI     	10 10 -1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 87)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_88
  label_86 : {
    aot_vmfetch(0x7e0a0513);
    op_arithI(L, l_addi, luai_numadd, TM_ADD, GETARG_k(i));
  }

  // 88	[75]	MMBINI   	10 1 7	; __sub
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 88)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_89
  label_87 : {
    aot_vmfetch(0x0780052d);
    Instruction pi = 0x7e0a0513;  /* original arith. expression */
    int imm = GETARG_sB(i);
    TMS tm = (TMS)GETARG_C(i);
    int flip = GETARG_k(i);
    StkId result = RA(pi);
    Protect(luaT_trybiniTM(L, s2v(ra), imm, flip, result, tm));
  }

  // 89	[75]	SETTABLE 	3 9 10
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 89)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_90
  label_88 : {
    aot_vmfetch(0x0a09018e);
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

  // 90	[76]	GETTABLE 	10 3 9
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 90)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_91
  label_89 : {
    aot_vmfetch(0x0903050a);
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

  // 91	[76]	GTI      	10 0 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 91)
  #undef  LUA_AOT_NEXT_JUMP
  #define LUA_AOT_NEXT_JUMP label_94
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_92
  label_90 : {
    aot_vmfetch(0x007f853e);
    op_orderI(L, l_gti, luai_numgt, 1, TM_LT);
  }

  // 92	[76]	JMP      	2	; to 95
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 92)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_93
  label_91 : {
    aot_vmfetch(0x800000b6);
    updatetrap(ci);
    goto label_94;
  }

  // 93	[77]	MOVE     	4 9
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 93)
  #undef  LUA_AOT_NEXT_JUMP
  #define LUA_AOT_NEXT_JUMP label_62
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_94
  label_92 : {
    aot_vmfetch(0x00090200);
    setobjs2s(L, ra, RB(i));
  }

  // 94	[77]	JMP      	-32	; to 63
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 94)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_95
  label_93 : {
    aot_vmfetch(0x7fffefb6);
    updatetrap(ci);
    goto label_62;
  }

  // 95	[79]	ADDI     	5 5 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 95)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_96
  label_94 : {
    aot_vmfetch(0x80050293);
    op_arithI(L, l_addi, luai_numadd, TM_ADD, GETARG_k(i));
  }

  // 96	[79]	MMBINI   	5 1 6	; __add
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 96)
  #undef  LUA_AOT_NEXT_JUMP
  #define LUA_AOT_NEXT_JUMP label_17
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_97
  label_95 : {
    aot_vmfetch(0x068002ad);
    Instruction pi = 0x80050293;  /* original arith. expression */
    int imm = GETARG_sB(i);
    TMS tm = (TMS)GETARG_C(i);
    int flip = GETARG_k(i);
    StkId result = RA(pi);
    Protect(luaT_trybiniTM(L, s2v(ra), imm, flip, result, tm));
  }

  // 97	[79]	JMP      	-80	; to 18
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 97)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_96 : {
    aot_vmfetch(0x7fffd7b6);
    updatetrap(ci);
    goto label_17;
  }

  // 98	[81]	RETURN0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 98)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_97 : {
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
  NULL
};

static const char LUA_AOT_MODULE_SOURCE_CODE[] = {
#if 0
  108, 111,  99,  97, 108,  32, 102, 117, 110,  99, 116, 105, 111, 110,  32, 102,
   97, 110, 110, 107, 117,  99, 104,  40,  78,  41,  10,  10,  32,  32,  32,  32,
  108, 111,  99,  97, 108,  32, 105, 110, 105, 116, 105,  97, 108,  95, 112, 101,
  114, 109,  32,  61,  32, 123, 125,  10,  32,  32,  32,  32, 102, 111, 114,  32,
  105,  32,  61,  32,  49,  44,  32,  78,  32, 100, 111,  10,  32,  32,  32,  32,
   32,  32,  32,  32, 105, 110, 105, 116, 105,  97, 108,  95, 112, 101, 114, 109,
   91, 105,  93,  32,  61,  32, 105,  10,  32,  32,  32,  32, 101, 110, 100,  10,
   10,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32, 112, 101, 114, 109,  32,
   61,  32, 123, 125,  32,  45,  45,  32,  87, 111, 114, 107,  32,  99, 111, 112,
  121,  44,  32,  97, 108, 108, 111,  99,  97, 116, 101, 100,  32, 111, 110,  99,
  101,  10,  10,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32,  99, 111, 117,
  110, 116,  32,  61,  32, 123, 125,  10,  32,  32,  32,  32,  99, 111, 117, 110,
  116,  91,  49,  93,  32,  61,  32,  48,  10,  32,  32,  32,  32, 108, 111,  99,
   97, 108,  32, 114,  32,  61,  32,  78,  10,  10,  32,  32,  32,  32, 108, 111,
   99,  97, 108,  32, 112, 101, 114, 109,  95,  99, 111, 117, 110, 116,  32,  61,
   32,  48,  10,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32, 109,  97, 120,
   95, 102, 108, 105, 112, 115,  32,  61,  32,  48,  10,  32,  32,  32,  32, 108,
  111,  99,  97, 108,  32,  99, 104, 101,  99, 107, 115, 117, 109,  32,  61,  32,
   48,  10,  10,  32,  32,  32,  32, 119, 104, 105, 108, 101,  32, 116, 114, 117,
  101,  32, 100, 111,  10,  10,  32,  32,  32,  32,  32,  32,  32,  32,  45,  45,
   32,  70, 108, 105, 112,  32, 116, 104, 101,  32, 112,  97, 110,  99,  97, 107,
  101, 115,  44,  32, 119, 111, 114, 107, 105, 110, 103,  32, 111, 110,  32,  97,
   32,  99, 111, 112, 121,  32, 111, 102,  32, 116, 104, 101,  32, 112, 101, 114,
  109, 117, 116,  97, 116, 105, 111, 110,  10,  10,  32,  32,  32,  32,  32,  32,
   32,  32, 100, 111,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,
   32, 102, 111, 114,  32, 105,  32,  61,  32,  49,  44,  32,  78,  32, 100, 111,
   10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,
   32, 112, 101, 114, 109,  91, 105,  93,  32,  61,  32, 105, 110, 105, 116, 105,
   97, 108,  95, 112, 101, 114, 109,  91, 105,  93,  10,  32,  32,  32,  32,  32,
   32,  32,  32,  32,  32,  32,  32, 101, 110, 100,  10,  10,  32,  32,  32,  32,
   32,  32,  32,  32,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32, 102, 108,
  105, 112, 115,  95,  99, 111, 117, 110, 116,  32,  61,  32,  48,  10,  32,  32,
   32,  32,  32,  32,  32,  32,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32,
  104,  32,  61,  32, 112, 101, 114, 109,  91,  49,  93,  10,  32,  32,  32,  32,
   32,  32,  32,  32,  32,  32,  32,  32, 119, 104, 105, 108, 101,  32, 104,  32,
   62,  32,  49,  32, 100, 111,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,
   32,  32,  32,  32,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32, 105,  32,
   61,  32,  49,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,
   32,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32, 106,  32,  61,  32, 104,
   10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,
   32,  32, 114, 101, 112, 101,  97, 116,  10,  32,  32,  32,  32,  32,  32,  32,
   32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32, 108, 111,  99,
   97, 108,  32,  97,  32,  61,  32, 112, 101, 114, 109,  91, 105,  93,  10,  32,
   32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,
   32,  32,  32, 108, 111,  99,  97, 108,  32,  98,  32,  61,  32, 112, 101, 114,
  109,  91, 106,  93,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,
   32,  32,  32,  32,  32,  32,  32,  32,  32, 112, 101, 114, 109,  91, 105,  93,
   32,  61,  32,  98,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,
   32,  32,  32,  32,  32,  32,  32,  32,  32, 112, 101, 114, 109,  91, 106,  93,
   32,  61,  32,  97,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,
   32,  32,  32,  32,  32,  32,  32,  32,  32, 105,  32,  61,  32, 105,  32,  43,
   32,  49,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,
   32,  32,  32,  32,  32,  32,  32, 106,  32,  61,  32, 106,  32,  45,  32,  49,
   10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,
   32, 117, 110, 116, 105, 108,  32, 105,  32,  62,  61,  32, 106,  10,  10,  32,
   32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32, 102,
  108, 105, 112, 115,  95,  99, 111, 117, 110, 116,  32,  61,  32, 102, 108, 105,
  112, 115,  95,  99, 111, 117, 110, 116,  32,  43,  32,  49,  10,  32,  32,  32,
   32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32, 104,  32,  61,
   32, 112, 101, 114, 109,  91,  49,  93,  10,  32,  32,  32,  32,  32,  32,  32,
   32,  32,  32,  32,  32, 101, 110, 100,  10,  10,  32,  32,  32,  32,  32,  32,
   32,  32,  32,  32,  32,  32, 105, 102,  32, 102, 108, 105, 112, 115,  95,  99,
  111, 117, 110, 116,  32,  62,  32, 109,  97, 120,  95, 102, 108, 105, 112, 115,
   32, 116, 104, 101, 110,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,
   32,  32,  32,  32,  32,  32, 109,  97, 120,  95, 102, 108, 105, 112, 115,  32,
   61,  32, 102, 108, 105, 112, 115,  95,  99, 111, 117, 110, 116,  10,  32,  32,
   32,  32,  32,  32,  32,  32,  32,  32,  32,  32, 101, 110, 100,  10,  10,  32,
   32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32, 105, 102,  32, 112, 101,
  114, 109,  95,  99, 111, 117, 110, 116,  32,  37,  32,  50,  32,  61,  61,  32,
   48,  32, 116, 104, 101, 110,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,
   32,  32,  32,  32,  32,  32,  32,  99, 104, 101,  99, 107, 115, 117, 109,  32,
   61,  32,  99, 104, 101,  99, 107, 115, 117, 109,  32,  43,  32, 102, 108, 105,
  112, 115,  95,  99, 111, 117, 110, 116,  10,  32,  32,  32,  32,  32,  32,  32,
   32,  32,  32,  32,  32, 101, 108, 115, 101,  10,  32,  32,  32,  32,  32,  32,
   32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  99, 104, 101,  99, 107, 115,
  117, 109,  32,  61,  32,  99, 104, 101,  99, 107, 115, 117, 109,  32,  45,  32,
  102, 108, 105, 112, 115,  95,  99, 111, 117, 110, 116,  10,  32,  32,  32,  32,
   32,  32,  32,  32,  32,  32,  32,  32, 101, 110, 100,  10,  32,  32,  32,  32,
   32,  32,  32,  32, 101, 110, 100,  10,  10,  32,  32,  32,  32,  32,  32,  32,
   32,  45,  45,  32,  71, 111,  32, 116, 111,  32, 110, 101, 120, 116,  32, 112,
  101, 114, 109, 117, 116,  97, 116, 105, 111, 110,  10,  10,  32,  32,  32,  32,
   32,  32,  32,  32, 119, 104, 105, 108, 101,  32, 114,  32,  62,  32,  49,  32,
  100, 111,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  99,
  111, 117, 110, 116,  91, 114,  93,  32,  61,  32, 114,  10,  32,  32,  32,  32,
   32,  32,  32,  32,  32,  32,  32,  32, 114,  32,  61,  32, 114,  32,  45,  32,
   49,  10,  32,  32,  32,  32,  32,  32,  32,  32, 101, 110, 100,  10,  10,  32,
   32,  32,  32,  32,  32,  32,  32, 119, 104, 105, 108, 101,  32, 116, 114, 117,
  101,  32, 100, 111,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,
   32, 105, 102,  32, 114,  32,  61,  61,  32,  78,  32, 116, 104, 101, 110,  10,
   32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,
  114, 101, 116, 117, 114, 110,  32, 123,  32,  99, 104, 101,  99, 107, 115, 117,
  109,  44,  32, 109,  97, 120,  95, 102, 108, 105, 112, 115,  32, 125,  10,  32,
   32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32, 101, 110, 100,  10,  10,
   32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32, 108, 111,  99,  97,
  108,  32, 116, 109, 112,  32,  61,  32, 105, 110, 105, 116, 105,  97, 108,  95,
  112, 101, 114, 109,  91,  49,  93,  10,  32,  32,  32,  32,  32,  32,  32,  32,
   32,  32,  32,  32, 102, 111, 114,  32, 105,  32,  61,  32,  49,  44,  32, 114,
   32, 100, 111,  10,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,  32,
   32,  32,  32,  32, 105, 110, 105, 116, 105,  97, 108,  95, 112, 101, 114, 109,
   91, 105,  93,  32,  61,  32, 105, 110, 105, 116, 105,  97, 108,  95, 112, 101,
  114, 109,  91, 105,  43,  49,  93,  10,  32,  32,  32,  32,  32,  32,  32,  32,
   32,  32,  32,  32, 101, 110, 100,  10,  32,  32,  32,  32,  32,  32,  32,  32,
   32,  32,  32,  32, 105, 110, 105, 116, 105,  97, 108,  95, 112, 101, 114, 109,
   91, 114,  43,  49,  93,  32,  61,  32, 116, 109, 112,  10,  10,  32,  32,  32,
   32,  32,  32,  32,  32,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32, 114,
   49,  32,  61,  32, 114,  43,  49,  10,  32,  32,  32,  32,  32,  32,  32,  32,
   32,  32,  32,  32,  99, 111, 117, 110, 116,  91, 114,  49,  93,  32,  61,  32,
   99, 111, 117, 110, 116,  91, 114,  49,  93,  32,  45,  32,  49,  10,  32,  32,
   32,  32,  32,  32,  32,  32,  32,  32,  32,  32, 105, 102,  32,  99, 111, 117,
  110, 116,  91, 114,  49,  93,  32,  62,  32,  48,  32, 116, 104, 101, 110,  32,
   98, 114, 101,  97, 107,  32, 101, 110, 100,  10,  32,  32,  32,  32,  32,  32,
   32,  32,  32,  32,  32,  32, 114,  32,  61,  32, 114,  49,  10,  32,  32,  32,
   32,  32,  32,  32,  32, 101, 110, 100,  10,  32,  32,  32,  32,  32,  32,  32,
   32, 112, 101, 114, 109,  95,  99, 111, 117, 110, 116,  32,  61,  32, 112, 101,
  114, 109,  95,  99, 111, 117, 110, 116,  32,  43,  32,  49,  10,  32,  32,  32,
   32, 101, 110, 100,  10, 101, 110, 100,  10,  10, 114, 101, 116, 117, 114, 110,
   32, 123,  10,  32,  32,  32,  32, 102,  97, 110, 110, 107, 117,  99, 104,  32,
   61,  32, 102,  97, 110, 110, 107, 117,  99, 104,  10, 125,  10,   0
#endif
};

#define LUA_AOT_LUAOPEN_NAME luaopen_benchmarks_fannkuchredux_luaot

#include "luaot_footer.c"
