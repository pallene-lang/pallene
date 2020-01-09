#include "luaot_header.c"
 
// source = @benchmarks/streamSieve/injectLua.lua
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
  
  // 2	[7]	CLOSURE  	0 0	; 0x13fd010
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
  
  // 3	[11]	CLOSURE  	1 1	; 0x13fd530
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
  
  // 4	[15]	CLOSURE  	2 2	; 0x13fd660
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
  
  // 5	[22]	CLOSURE  	3 3	; 0x13fd7b0
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
  
  // 6	[28]	LOADNIL  	4 1	; 2 out
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
  
  // 7	[32]	CLOSURE  	6 4	; 0x13fe030
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
  
  // 8	[30]	MOVE     	4 6
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_09
  label_07 : {
    aot_vmfetch(0x00060200);
    setobjs2s(L, ra, RB(i));
  }
  
  // 9	[36]	CLOSURE  	6 5	; 0x13fe140
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
  
  // 10	[34]	MOVE     	5 6
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 10)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_11
  label_09 : {
    aot_vmfetch(0x00060280);
    setobjs2s(L, ra, RB(i));
  }
  
  // 11	[40]	LOADNIL  	6 1	; 2 out
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
  
  // 12	[52]	CLOSURE  	8 6	; 0x13fe2f0
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
  
  // 13	[42]	MOVE     	6 8
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 13)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_14
  label_12 : {
    aot_vmfetch(0x00080300);
    setobjs2s(L, ra, RB(i));
  }
  
  // 14	[56]	CLOSURE  	8 7	; 0x13fe570
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
  
  // 15	[54]	MOVE     	7 8
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 15)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_16
  label_14 : {
    aot_vmfetch(0x00080380);
    setobjs2s(L, ra, RB(i));
  }
  
  // 16	[60]	LOADNIL  	8 1	; 2 out
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
  
  // 17	[67]	CLOSURE  	10 8	; 0x13fdf50
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
  
  // 18	[62]	MOVE     	8 10
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 18)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_19
  label_17 : {
    aot_vmfetch(0x000a0400);
    setobjs2s(L, ra, RB(i));
  }
  
  // 19	[71]	CLOSURE  	10 9	; 0x13fe9f0
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
  
  // 20	[69]	MOVE     	9 10
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 20)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_21
  label_19 : {
    aot_vmfetch(0x000a0480);
    setobjs2s(L, ra, RB(i));
  }
  
  // 21	[78]	CLOSURE  	10 10	; 0x13feb00
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
  
  // 22	[80]	NEWTABLE 	11 5 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 22)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_23
  label_21 : {
    aot_vmfetch(0x00050591);
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
  
  // 23	[80]	EXTRAARG 	0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 23)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_24
  label_22 : {
    aot_vmfetch(0x00000050);
    lua_assert(0);
  }
  
  // 24	[81]	SETFIELD 	11 0 0	; "make_stream"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 24)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_25
  label_23 : {
    aot_vmfetch(0x00000590);
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
  
  // 25	[82]	SETFIELD 	11 1 1	; "stream_head"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 25)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_26
  label_24 : {
    aot_vmfetch(0x01010590);
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
  
  // 26	[83]	SETFIELD 	11 2 2	; "stream_tail"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 26)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_27
  label_25 : {
    aot_vmfetch(0x02020590);
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
  
  // 27	[84]	SETFIELD 	11 3 3	; "stream_get"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 27)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_28
  label_26 : {
    aot_vmfetch(0x03030590);
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
  
  // 28	[86]	SETFIELD 	11 4 4	; "count_from"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 28)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_29
  label_27 : {
    aot_vmfetch(0x04040590);
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
  
  // 29	[87]	SETFIELD 	11 5 6	; "sift"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 29)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_30
  label_28 : {
    aot_vmfetch(0x06050590);
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
  
  // 30	[88]	SETFIELD 	11 6 8	; "sieve"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 30)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_31
  label_29 : {
    aot_vmfetch(0x08060590);
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
  
  // 31	[90]	SETFIELD 	11 7 10	; "get_prime"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 31)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_32
  label_30 : {
    aot_vmfetch(0x0a070590);
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
  
  // 32	[97]	CLOSURE  	12 11	; 0x13fec80
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 32)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_33
  label_31 : {
    aot_vmfetch(0x0005864d);
    Proto *p = cl->p->p[GETARG_Bx(i)];
    halfProtect(pushclosure(L, p, cl->upvals, base, ra));
    checkGC(L, ra + 1);
  }
  
  // 33	[97]	SETFIELD 	11 8 12	; "injectStream"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 33)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_34
  label_32 : {
    aot_vmfetch(0x0c080590);
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
  
  // 34	[103]	CLOSURE  	12 12	; 0x13fe930
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 34)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_35
  label_33 : {
    aot_vmfetch(0x0006064d);
    Proto *p = cl->p->p[GETARG_Bx(i)];
    halfProtect(pushclosure(L, p, cl->upvals, base, ra));
    checkGC(L, ra + 1);
  }
  
  // 35	[103]	SETFIELD 	11 9 12	; "injectMain"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 35)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_36
  label_34 : {
    aot_vmfetch(0x0c090590);
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
  
  // 36	[104]	RETURN   	11 2 1	; 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 36)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_35 : {
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
  
  // 37	[104]	RETURN   	11 1 1	; 0 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 37)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_36 : {
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
 
// source = @benchmarks/streamSieve/injectLua.lua
// lines: 5 - 7
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
 
  // 1	[6]	NEWTABLE 	3 0 3
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
  
  // 2	[6]	EXTRAARG 	0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x00000050);
    lua_assert(0);
  }
  
  // 3	[6]	MOVE     	4 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x00000200);
    setobjs2s(L, ra, RB(i));
  }
  
  // 4	[6]	MOVE     	5 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0x00010280);
    setobjs2s(L, ra, RB(i));
  }
  
  // 5	[6]	MOVE     	6 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x00020300);
    setobjs2s(L, ra, RB(i));
  }
  
  // 6	[6]	SETLIST  	3 3 0
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
  
  // 7	[6]	RETURN1  	3
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
  
  // 8	[7]	RETURN0  	
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
 
// source = @benchmarks/streamSieve/injectLua.lua
// lines: 9 - 11
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
 
  // 1	[10]	GETI     	1 0 1
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
  
  // 2	[10]	RETURN1  	1
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
  
  // 3	[11]	RETURN0  	
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
 
// source = @benchmarks/streamSieve/injectLua.lua
// lines: 13 - 15
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
 
  // 1	[14]	GETI     	1 0 3
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
  
  // 2	[14]	GETI     	2 0 2
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
  
  // 3	[14]	CALL     	1 2 2	; 1 in 1 out
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
  
  // 4	[14]	RETURN1  	1
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
  
  // 5	[15]	RETURN0  	
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
 
// source = @benchmarks/streamSieve/injectLua.lua
// lines: 17 - 22
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
 
  // 1	[18]	LOADI    	2 1
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
  
  // 2	[18]	ADDI     	3 1 -1 
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x7e010193);
    op_arithI(L, l_addi, luai_numadd, TM_ADD, GETARG_k(i));
  }
  
  // 3	[18]	MMBINI   	1 1 7	; __sub
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
  
  // 4	[18]	LOADI    	4 1
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
  
  // 5	[18]	FORPREP  	2 4	; to 10
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
  
  // 6	[19]	GETUPVAL 	6 0	; stream_tail
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
  
  // 7	[19]	MOVE     	7 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_08
  label_06 : {
    aot_vmfetch(0x00000380);
    setobjs2s(L, ra, RB(i));
  }
  
  // 8	[19]	CALL     	6 2 2	; 1 in 1 out
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
  
  // 9	[19]	MOVE     	0 6
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 9)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_10
  label_08 : {
    aot_vmfetch(0x00060000);
    setobjs2s(L, ra, RB(i));
  }
  
  // 10	[18]	FORLOOP  	2 5	; to 6
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
  
  // 11	[21]	GETUPVAL 	2 1	; stream_head
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
  
  // 12	[21]	MOVE     	3 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 12)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_13
  label_11 : {
    aot_vmfetch(0x00000180);
    setobjs2s(L, ra, RB(i));
  }
  
  // 13	[21]	CALL     	2 2 2	; 1 in 1 out
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
  
  // 14	[21]	RETURN1  	2
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
  
  // 15	[22]	RETURN0  	
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
 
// source = @benchmarks/streamSieve/injectLua.lua
// lines: 30 - 32
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
 
  // 1	[31]	GETUPVAL 	1 0	; make_stream
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
  
  // 2	[31]	MOVE     	2 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x00000100);
    setobjs2s(L, ra, RB(i));
  }
  
  // 3	[31]	MOVE     	3 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 3)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_04
  label_02 : {
    aot_vmfetch(0x00000180);
    setobjs2s(L, ra, RB(i));
  }
  
  // 4	[31]	GETUPVAL 	4 1	; _tail1
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
  
  // 5	[31]	CALL     	1 4 2	; 3 in 1 out
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
  
  // 6	[31]	RETURN1  	1
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
  
  // 7	[32]	RETURN0  	
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
 
// source = @benchmarks/streamSieve/injectLua.lua
// lines: 34 - 36
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
 
  // 1	[35]	GETUPVAL 	1 0	; count_from
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
  
  // 2	[35]	ADDI     	2 0 1 
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x80000113);
    op_arithI(L, l_addi, luai_numadd, TM_ADD, GETARG_k(i));
  }
  
  // 3	[35]	MMBINI   	0 1 6	; __add
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
  
  // 4	[35]	CALL     	1 2 2	; 1 in 1 out
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
  
  // 5	[35]	RETURN1  	1
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
  
  // 6	[36]	RETURN0  	
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
 
// source = @benchmarks/streamSieve/injectLua.lua
// lines: 42 - 52
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
 
  // 1	[43]	GETUPVAL 	2 0	; stream_head
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
  
  // 2	[43]	MOVE     	3 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x00010180);
    setobjs2s(L, ra, RB(i));
  }
  
  // 3	[43]	CALL     	2 2 2	; 1 in 1 out
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
  
  // 4	[44]	GETUPVAL 	3 1	; stream_tail
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
  
  // 5	[44]	MOVE     	4 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x00010200);
    setobjs2s(L, ra, RB(i));
  }
  
  // 6	[44]	CALL     	3 2 2	; 1 in 1 out
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
  
  // 7	[45]	MOD      	4 2 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_08
  label_06 : {
    aot_vmfetch(0x00020223);
    op_arith(L, luaV_mod, luaV_modf);
  }
  
  // 8	[45]	MMBIN    	2 0 9	; __mod
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
  
  // 9	[45]	EQI      	4 0 0
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
  
  // 10	[45]	JMP      	10	; to 21
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
  
  // 11	[46]	MOVE     	1 3
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 11)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_12
  label_10 : {
    aot_vmfetch(0x00030080);
    setobjs2s(L, ra, RB(i));
  }
  
  // 12	[47]	GETUPVAL 	4 0	; stream_head
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
  
  // 13	[47]	MOVE     	5 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 13)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_14
  label_12 : {
    aot_vmfetch(0x00010280);
    setobjs2s(L, ra, RB(i));
  }
  
  // 14	[47]	CALL     	4 2 2	; 1 in 1 out
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
  
  // 15	[47]	MOVE     	2 4
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 15)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_16
  label_14 : {
    aot_vmfetch(0x00040100);
    setobjs2s(L, ra, RB(i));
  }
  
  // 16	[48]	GETUPVAL 	4 1	; stream_tail
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
  
  // 17	[48]	MOVE     	5 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 17)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_18
  label_16 : {
    aot_vmfetch(0x00010280);
    setobjs2s(L, ra, RB(i));
  }
  
  // 18	[48]	CALL     	4 2 2	; 1 in 1 out
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
  
  // 19	[48]	MOVE     	3 4
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
  
  // 20	[48]	JMP      	-14	; to 7
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
  
  // 21	[50]	NEWTABLE 	4 0 2
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
  
  // 22	[50]	EXTRAARG 	0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 22)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_23
  label_21 : {
    aot_vmfetch(0x00000050);
    lua_assert(0);
  }
  
  // 23	[50]	MOVE     	5 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 23)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_24
  label_22 : {
    aot_vmfetch(0x00000280);
    setobjs2s(L, ra, RB(i));
  }
  
  // 24	[50]	MOVE     	6 3
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 24)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_25
  label_23 : {
    aot_vmfetch(0x00030300);
    setobjs2s(L, ra, RB(i));
  }
  
  // 25	[50]	SETLIST  	4 2 0
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
  
  // 26	[51]	GETUPVAL 	5 2	; make_stream
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
  
  // 27	[51]	MOVE     	6 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 27)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_28
  label_26 : {
    aot_vmfetch(0x00020300);
    setobjs2s(L, ra, RB(i));
  }
  
  // 28	[51]	MOVE     	7 4
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 28)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_29
  label_27 : {
    aot_vmfetch(0x00040380);
    setobjs2s(L, ra, RB(i));
  }
  
  // 29	[51]	GETUPVAL 	8 3	; _tail2
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
  
  // 30	[51]	CALL     	5 4 2	; 3 in 1 out
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
  
  // 31	[51]	RETURN1  	5
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
  
  // 32	[52]	RETURN0  	
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
 
// source = @benchmarks/streamSieve/injectLua.lua
// lines: 54 - 56
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
 
  // 1	[55]	GETUPVAL 	1 0	; sift
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
  
  // 2	[55]	GETI     	2 0 1
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
  
  // 3	[55]	GETI     	3 0 2
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
  
  // 4	[55]	CALL     	1 3 2	; 2 in 1 out
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
  
  // 5	[55]	RETURN1  	1
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
  
  // 6	[56]	RETURN0  	
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
 
// source = @benchmarks/streamSieve/injectLua.lua
// lines: 62 - 67
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
 
  // 1	[63]	GETUPVAL 	1 0	; stream_head
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
  
  // 2	[63]	MOVE     	2 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x00000100);
    setobjs2s(L, ra, RB(i));
  }
  
  // 3	[63]	CALL     	1 2 2	; 1 in 1 out
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
  
  // 4	[64]	GETUPVAL 	2 1	; stream_tail
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
  
  // 5	[64]	MOVE     	3 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x00000180);
    setobjs2s(L, ra, RB(i));
  }
  
  // 6	[64]	CALL     	2 2 2	; 1 in 1 out
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
  
  // 7	[65]	NEWTABLE 	3 0 2
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
  
  // 8	[65]	EXTRAARG 	0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_09
  label_07 : {
    aot_vmfetch(0x00000050);
    lua_assert(0);
  }
  
  // 9	[65]	MOVE     	4 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 9)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_10
  label_08 : {
    aot_vmfetch(0x00010200);
    setobjs2s(L, ra, RB(i));
  }
  
  // 10	[65]	MOVE     	5 2
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 10)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_11
  label_09 : {
    aot_vmfetch(0x00020280);
    setobjs2s(L, ra, RB(i));
  }
  
  // 11	[65]	SETLIST  	3 2 0
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
  
  // 12	[66]	GETUPVAL 	4 2	; make_stream
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
  
  // 13	[66]	MOVE     	5 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 13)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_14
  label_12 : {
    aot_vmfetch(0x00010280);
    setobjs2s(L, ra, RB(i));
  }
  
  // 14	[66]	MOVE     	6 3
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 14)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_15
  label_13 : {
    aot_vmfetch(0x00030300);
    setobjs2s(L, ra, RB(i));
  }
  
  // 15	[66]	GETUPVAL 	7 3	; _tail3
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
  
  // 16	[66]	CALL     	4 4 2	; 3 in 1 out
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
  
  // 17	[66]	RETURN1  	4
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
  
  // 18	[67]	RETURN0  	
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
 
// source = @benchmarks/streamSieve/injectLua.lua
// lines: 69 - 71
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
 
  // 1	[70]	GETUPVAL 	1 0	; sieve
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
  
  // 2	[70]	GETUPVAL 	2 1	; sift
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
  
  // 3	[70]	GETI     	3 0 1
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
  
  // 4	[70]	GETI     	4 0 2
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
  
  // 5	[70]	CALL     	2 3 0	; 2 in all out
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
  
  // 6	[70]	CALL     	1 0 2	; all in 1 out
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
  
  // 7	[70]	RETURN1  	1
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
  
  // 8	[71]	RETURN0  	
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
 
// source = @benchmarks/streamSieve/injectLua.lua
// lines: 75 - 78
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
 
  // 1	[76]	GETUPVAL 	1 0	; sieve
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
  
  // 2	[76]	GETUPVAL 	2 1	; count_from
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
  
  // 3	[76]	LOADI    	3 2
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
  
  // 4	[76]	CALL     	2 2 0	; 1 in all out
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
  
  // 5	[76]	CALL     	1 0 2	; all in 1 out
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
  
  // 6	[77]	GETUPVAL 	2 2	; stream_get
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
  
  // 7	[77]	MOVE     	3 1
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 7)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_08
  label_06 : {
    aot_vmfetch(0x00010180);
    setobjs2s(L, ra, RB(i));
  }
  
  // 8	[77]	MOVE     	4 0
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_09
  label_07 : {
    aot_vmfetch(0x00000200);
    setobjs2s(L, ra, RB(i));
  }
  
  // 9	[77]	CALL     	2 3 2	; 2 in 1 out
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
  
  // 10	[77]	RETURN1  	2
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
  
  // 11	[78]	RETURN0  	
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
 
// source = @benchmarks/streamSieve/injectLua.lua
// lines: 92 - 97
static
void magic_implementation_12(lua_State *L, CallInfo *ci)
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
 
  // 1	[93]	GETTABUP 	1 1 0	; _ENV "assert"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 1)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_02
  label_00 : {
    aot_vmfetch(0x00010089);
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
  
  // 2	[93]	GETFIELD 	2 0 1	; "make_stream_pln"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x0100010c);
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
  
  // 3	[93]	CALL     	1 2 2	; 1 in 1 out
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
  
  // 4	[93]	SETUPVAL 	1 0	; make_stream
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0x00000088);
    UpVal *uv = cl->upvals[GETARG_B(i)];
    setobj(L, uv->v, s2v(ra));
    luaC_barrier(L, uv, s2v(ra));
  }
  
  // 5	[94]	GETTABUP 	1 1 0	; _ENV "assert"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x00010089);
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
  
  // 6	[94]	GETFIELD 	2 0 2	; "stream_head_pln"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_07
  label_05 : {
    aot_vmfetch(0x0200010c);
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
  
  // 7	[94]	CALL     	1 2 2	; 1 in 1 out
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
  
  // 8	[94]	SETUPVAL 	1 2	; stream_head
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_09
  label_07 : {
    aot_vmfetch(0x00020088);
    UpVal *uv = cl->upvals[GETARG_B(i)];
    setobj(L, uv->v, s2v(ra));
    luaC_barrier(L, uv, s2v(ra));
  }
  
  // 9	[95]	GETTABUP 	1 1 0	; _ENV "assert"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 9)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_10
  label_08 : {
    aot_vmfetch(0x00010089);
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
  
  // 10	[95]	GETFIELD 	2 0 3	; "stream_tail_pln"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 10)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_11
  label_09 : {
    aot_vmfetch(0x0300010c);
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
  
  // 11	[95]	CALL     	1 2 2	; 1 in 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 11)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_12
  label_10 : {
    aot_vmfetch(0x020200c2);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 12	[95]	SETUPVAL 	1 3	; stream_tail
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 12)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_13
  label_11 : {
    aot_vmfetch(0x00030088);
    UpVal *uv = cl->upvals[GETARG_B(i)];
    setobj(L, uv->v, s2v(ra));
    luaC_barrier(L, uv, s2v(ra));
  }
  
  // 13	[96]	GETTABUP 	1 1 0	; _ENV "assert"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 13)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_14
  label_12 : {
    aot_vmfetch(0x00010089);
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
  
  // 14	[96]	GETFIELD 	2 0 4	; "stream_get_pln"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 14)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_15
  label_13 : {
    aot_vmfetch(0x0400010c);
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
  
  // 15	[96]	CALL     	1 2 2	; 1 in 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 15)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_16
  label_14 : {
    aot_vmfetch(0x020200c2);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 16	[96]	SETUPVAL 	1 4	; stream_get
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 16)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_15 : {
    aot_vmfetch(0x00040088);
    UpVal *uv = cl->upvals[GETARG_B(i)];
    setobj(L, uv->v, s2v(ra));
    luaC_barrier(L, uv, s2v(ra));
  }
  
  // 17	[97]	RETURN0  	
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 17)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_16 : {
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
 
// source = @benchmarks/streamSieve/injectLua.lua
// lines: 99 - 103
static
void magic_implementation_13(lua_State *L, CallInfo *ci)
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
 
  // 1	[100]	GETTABUP 	1 1 0	; _ENV "assert"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 1)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_02
  label_00 : {
    aot_vmfetch(0x00010089);
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
  
  // 2	[100]	GETFIELD 	2 0 1	; "count_from_pln"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 2)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_03
  label_01 : {
    aot_vmfetch(0x0100010c);
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
  
  // 3	[100]	CALL     	1 2 2	; 1 in 1 out
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
  
  // 4	[100]	SETUPVAL 	1 0	; count_from
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 4)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_05
  label_03 : {
    aot_vmfetch(0x00000088);
    UpVal *uv = cl->upvals[GETARG_B(i)];
    setobj(L, uv->v, s2v(ra));
    luaC_barrier(L, uv, s2v(ra));
  }
  
  // 5	[101]	GETTABUP 	1 1 0	; _ENV "assert"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 5)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_06
  label_04 : {
    aot_vmfetch(0x00010089);
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
  
  // 6	[101]	GETFIELD 	2 0 2	; "sift_pln"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 6)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_07
  label_05 : {
    aot_vmfetch(0x0200010c);
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
  
  // 7	[101]	CALL     	1 2 2	; 1 in 1 out
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
  
  // 8	[101]	SETUPVAL 	1 2	; sift
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 8)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_09
  label_07 : {
    aot_vmfetch(0x00020088);
    UpVal *uv = cl->upvals[GETARG_B(i)];
    setobj(L, uv->v, s2v(ra));
    luaC_barrier(L, uv, s2v(ra));
  }
  
  // 9	[102]	GETTABUP 	1 1 0	; _ENV "assert"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 9)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_10
  label_08 : {
    aot_vmfetch(0x00010089);
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
  
  // 10	[102]	GETFIELD 	2 0 3	; "sieve_pln"
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 10)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_11
  label_09 : {
    aot_vmfetch(0x0300010c);
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
  
  // 11	[102]	CALL     	1 2 2	; 1 in 1 out
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 11)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  #define LUA_AOT_SKIP1 label_12
  label_10 : {
    aot_vmfetch(0x020200c2);
    int b = GETARG_B(i);
    int nresults = GETARG_C(i) - 1;
    if (b != 0)  /* fixed number of arguments? */
      L->top = ra + b;  /* top signals number of arguments */
    /* else previous instruction set top */
    ProtectNT(luaD_call(L, ra, nresults));
  }
  
  // 12	[102]	SETUPVAL 	1 3	; sieve
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 12)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_11 : {
    aot_vmfetch(0x00030088);
    UpVal *uv = cl->upvals[GETARG_B(i)];
    setobj(L, uv->v, s2v(ra));
    luaC_barrier(L, uv, s2v(ra));
  }
  
  // 13	[103]	RETURN0  	
  #undef  LUA_AOT_PC
  #define LUA_AOT_PC (function_code + 13)
  #undef  LUA_AOT_NEXT_JUMP
  #undef  LUA_AOT_SKIP1
  label_12 : {
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
  magic_implementation_12,
  magic_implementation_13,
  NULL
};
 
static const char LUA_AOT_MODULE_SOURCE_CODE[] = {
   45,  45,  32,  83, 105, 109, 112, 108, 101,  32, 115, 116, 114, 101,  97, 109, 
  115,  32, 108, 105,  98, 114,  97, 114, 121,  32, 102, 111, 114,  32,  98, 117, 
  105, 108, 100, 105, 110, 103,  32, 105, 110, 102, 105, 110, 105, 116, 101,  32, 
  108, 105, 115, 116, 115,  46,  10,  45,  45,  32,  66,  97, 115, 101, 100,  32, 
  111, 110,  32, 116, 104, 101,  32, 105, 109, 112, 108, 101, 109, 101, 110, 116, 
   97, 116, 105, 111, 110,  32, 102, 114, 111, 109,  32,  82,  97,  99, 107, 101, 
  116,  44,  32,  98, 117, 116,  32, 109, 111, 100, 105, 102, 105, 101, 100,  32, 
  116, 111,  32, 117, 115, 101,  32, 101, 120, 112, 108, 105,  99, 105, 116,  10, 
   45,  45,  32, 112,  97, 114,  97, 109, 101, 116, 101, 114, 115,  32, 105, 110, 
  115, 116, 101,  97, 100,  32, 111, 102,  32,  99, 108, 111, 115, 117, 114, 101, 
  115,  10,  10, 108, 111,  99,  97, 108,  32, 102, 117, 110,  99, 116, 105, 111, 
  110,  32, 109,  97, 107, 101,  95, 115, 116, 114, 101,  97, 109,  40, 104, 101, 
   97, 100,  44,  32, 115, 116,  97, 116, 101,  44,  32, 103, 101, 116,  95, 116, 
   97, 105, 108,  41,  10,  32,  32,  32,  32, 114, 101, 116, 117, 114, 110,  32, 
  123,  32, 104, 101,  97, 100,  44,  32, 115, 116,  97, 116, 101,  44,  32, 103, 
  101, 116,  95, 116,  97, 105, 108,  32, 125,  10, 101, 110, 100,  10,  10, 108, 
  111,  99,  97, 108,  32, 102, 117, 110,  99, 116, 105, 111, 110,  32, 115, 116, 
  114, 101,  97, 109,  95, 104, 101,  97, 100,  40, 115, 116,  41,  10,  32,  32, 
   32,  32, 114, 101, 116, 117, 114, 110,  32, 115, 116,  91,  49,  93,  10, 101, 
  110, 100,  10,  10, 108, 111,  99,  97, 108,  32, 102, 117, 110,  99, 116, 105, 
  111, 110,  32, 115, 116, 114, 101,  97, 109,  95, 116,  97, 105, 108,  40, 115, 
  116,  41,  10,  32,  32,  32,  32, 114, 101, 116, 117, 114, 110,  32,  40, 115, 
  116,  91,  51,  93,  40, 115, 116,  91,  50,  93,  41,  41,  10, 101, 110, 100, 
   10,  10, 108, 111,  99,  97, 108,  32, 102, 117, 110,  99, 116, 105, 111, 110, 
   32, 115, 116, 114, 101,  97, 109,  95, 103, 101, 116,  40, 115, 116,  44,  32, 
  110,  41,  10,  32,  32,  32,  32, 102, 111, 114,  32,  95,  32,  61,  32,  49, 
   44,  32, 110,  45,  49,  32, 100, 111,  10,  32,  32,  32,  32,  32,  32,  32, 
   32, 115, 116,  32,  61,  32, 115, 116, 114, 101,  97, 109,  95, 116,  97, 105, 
  108,  40, 115, 116,  41,  10,  32,  32,  32,  32, 101, 110, 100,  10,  32,  32, 
   32,  32, 114, 101, 116, 117, 114, 110,  32,  40, 115, 116, 114, 101,  97, 109, 
   95, 104, 101,  97, 100,  40, 115, 116,  41,  41,  10, 101, 110, 100,  10,  10, 
   45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45, 
   45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45, 
   45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  45,  10,  10, 
   45,  45,  32,  66, 117, 105, 108, 100,  32,  97,  32, 115, 116, 114, 101,  97, 
  109,  32, 111, 102,  32, 105, 110, 116, 101, 103, 101, 114, 115,  32, 115, 116, 
   97, 114, 116, 105, 110, 103,  32, 102, 114, 111, 109,  32,  49,  10,  10, 108, 
  111,  99,  97, 108,  32,  99, 111, 117, 110, 116,  95, 102, 114, 111, 109,  44, 
   32,  95, 116,  97, 105, 108,  49,  10,  10, 102, 117, 110,  99, 116, 105, 111, 
  110,  32,  99, 111, 117, 110, 116,  95, 102, 114, 111, 109,  40, 110,  41,  10, 
   32,  32,  32,  32, 114, 101, 116, 117, 114, 110,  32,  40, 109,  97, 107, 101, 
   95, 115, 116, 114, 101,  97, 109,  40, 110,  44,  32, 110,  44,  32,  95, 116, 
   97, 105, 108,  49,  41,  41,  10, 101, 110, 100,  10,  10, 102, 117, 110,  99, 
  116, 105, 111, 110,  32,  95, 116,  97, 105, 108,  49,  40, 105,  41,  10,  32, 
   32,  32,  32, 114, 101, 116, 117, 114, 110,  32,  40,  99, 111, 117, 110, 116, 
   95, 102, 114, 111, 109,  40, 105,  43,  49,  41,  41,  10, 101, 110, 100,  10, 
   10,  45,  45,  32,  70, 105, 108, 116, 101, 114,  32,  97, 108, 108,  32, 109, 
  117, 108, 116, 105, 112, 108, 101, 115,  32, 111, 102,  32, 110,  10,  10, 108, 
  111,  99,  97, 108,  32, 115, 105, 102, 116,  44,  32,  95, 116,  97, 105, 108, 
   50,  10,  10, 102, 117, 110,  99, 116, 105, 111, 110,  32, 115, 105, 102, 116, 
   40, 110,  44,  32, 115, 116,  41,  10,  32,  32,  32,  32, 108, 111,  99,  97, 
  108,  32, 104, 100,  32,  61,  32, 115, 116, 114, 101,  97, 109,  95, 104, 101, 
   97, 100,  40, 115, 116,  41,  10,  32,  32,  32,  32, 108, 111,  99,  97, 108, 
   32, 116, 108,  32,  61,  32, 115, 116, 114, 101,  97, 109,  95, 116,  97, 105, 
  108,  40, 115, 116,  41,  10,  32,  32,  32,  32, 119, 104, 105, 108, 101,  32, 
  104, 100,  32,  37,  32, 110,  32,  61,  61,  32,  48,  32, 100, 111,  10,  32, 
   32,  32,  32,  32,  32,  32,  32, 115, 116,  32,  61,  32, 116, 108,  10,  32, 
   32,  32,  32,  32,  32,  32,  32, 104, 100,  32,  61,  32, 115, 116, 114, 101, 
   97, 109,  95, 104, 101,  97, 100,  40, 115, 116,  41,  10,  32,  32,  32,  32, 
   32,  32,  32,  32, 116, 108,  32,  61,  32, 115, 116, 114, 101,  97, 109,  95, 
  116,  97, 105, 108,  40, 115, 116,  41,  10,  32,  32,  32,  32, 101, 110, 100, 
   10,  32,  32,  32,  32, 108, 111,  99,  97, 108,  32, 115, 116,  97, 116, 101, 
   32,  61,  32, 123,  32, 110,  44,  32, 116, 108,  32, 125,  10,  32,  32,  32, 
   32, 114, 101, 116, 117, 114, 110,  32,  40, 109,  97, 107, 101,  95, 115, 116, 
  114, 101,  97, 109,  40, 104, 100,  44,  32, 115, 116,  97, 116, 101,  44,  32, 
   95, 116,  97, 105, 108,  50,  41,  41,  10, 101, 110, 100,  10,  10, 102, 117, 
  110,  99, 116, 105, 111, 110,  32,  95, 116,  97, 105, 108,  50,  40, 115, 116, 
   97, 116, 101,  41,  10,  32,  32,  32,  32, 114, 101, 116, 117, 114, 110,  32, 
   40, 115, 105, 102, 116,  40, 115, 116,  97, 116, 101,  91,  49,  93,  44,  32, 
  115, 116,  97, 116, 101,  91,  50,  93,  41,  41,  10, 101, 110, 100,  10,  10, 
   45,  45,  32,  78,  97, 105, 118, 101,  32, 115, 105, 101, 118, 101,  32, 111, 
  102,  32,  69, 114,  97, 115, 116, 104, 111, 115, 116, 101, 110, 101, 115,  10, 
   10, 108, 111,  99,  97, 108,  32, 115, 105, 101, 118, 101,  44,  32,  95, 116, 
   97, 105, 108,  51,  10,  10, 102, 117, 110,  99, 116, 105, 111, 110,  32, 115, 
  105, 101, 118, 101,  40, 115, 116,  41,  10,  32,  32,  32,  32, 108, 111,  99, 
   97, 108,  32, 110,  32,  32,  61,  32, 115, 116, 114, 101,  97, 109,  95, 104, 
  101,  97, 100,  40, 115, 116,  41,  10,  32,  32,  32,  32, 108, 111,  99,  97, 
  108,  32, 116, 108,  32,  61,  32, 115, 116, 114, 101,  97, 109,  95, 116,  97, 
  105, 108,  40, 115, 116,  41,  10,  32,  32,  32,  32, 108, 111,  99,  97, 108, 
   32, 115, 116,  97, 116, 101,  32,  61,  32, 123,  32, 110,  44,  32, 116, 108, 
   32, 125,  10,  32,  32,  32,  32, 114, 101, 116, 117, 114, 110,  32,  40, 109, 
   97, 107, 101,  95, 115, 116, 114, 101,  97, 109,  40, 110,  44,  32, 115, 116, 
   97, 116, 101,  44,  32,  95, 116,  97, 105, 108,  51,  41,  41,  10, 101, 110, 
  100,  10,  10, 102, 117, 110,  99, 116, 105, 111, 110,  32,  95, 116,  97, 105, 
  108,  51,  40, 115, 116,  97, 116, 101,  41,  10,  32,  32,  32,  32, 114, 101, 
  116, 117, 114, 110,  32,  40, 115, 105, 101, 118, 101,  40, 115, 105, 102, 116, 
   40, 115, 116,  97, 116, 101,  91,  49,  93,  44,  32, 115, 116,  97, 116, 101, 
   91,  50,  93,  41,  41,  41,  10, 101, 110, 100,  10,  10,  45,  45,  10,  10, 
  108, 111,  99,  97, 108,  32, 102, 117, 110,  99, 116, 105, 111, 110,  32, 103, 
  101, 116,  95, 112, 114, 105, 109, 101,  40, 110,  41,  10,  32,  32,  32,  32, 
  108, 111,  99,  97, 108,  32, 112, 114, 105, 109, 101,  95, 115, 116, 114, 101, 
   97, 109,  32,  61,  32, 115, 105, 101, 118, 101,  40,  99, 111, 117, 110, 116, 
   95, 102, 114, 111, 109,  40,  50,  41,  41,  10,  32,  32,  32,  32, 114, 101, 
  116, 117, 114, 110,  32,  40, 115, 116, 114, 101,  97, 109,  95, 103, 101, 116, 
   40, 112, 114, 105, 109, 101,  95, 115, 116, 114, 101,  97, 109,  44,  32, 110, 
   41,  41,  10, 101, 110, 100,  10,  10, 114, 101, 116, 117, 114, 110,  32, 123, 
   10,  32,  32,  32,  32, 109,  97, 107, 101,  95, 115, 116, 114, 101,  97, 109, 
   32,  61,  32, 109,  97, 107, 101,  95, 115, 116, 114, 101,  97, 109,  44,  10, 
   32,  32,  32,  32, 115, 116, 114, 101,  97, 109,  95, 104, 101,  97, 100,  32, 
   61,  32, 115, 116, 114, 101,  97, 109,  95, 104, 101,  97, 100,  44,  10,  32, 
   32,  32,  32, 115, 116, 114, 101,  97, 109,  95, 116,  97, 105, 108,  32,  61, 
   32, 115, 116, 114, 101,  97, 109,  95, 116,  97, 105, 108,  44,  10,  32,  32, 
   32,  32, 115, 116, 114, 101,  97, 109,  95, 103, 101, 116,  32,  32,  61,  32, 
  115, 116, 114, 101,  97, 109,  95, 103, 101, 116,  44,  10,  10,  32,  32,  32, 
   32,  99, 111, 117, 110, 116,  95, 102, 114, 111, 109,  32,  32,  61,  32,  99, 
  111, 117, 110, 116,  95, 102, 114, 111, 109,  44,  10,  32,  32,  32,  32, 115, 
  105, 102, 116,  32,  32,  32,  32,  32,  32,  32,  32,  61,  32, 115, 105, 102, 
  116,  44,  10,  32,  32,  32,  32, 115, 105, 101, 118, 101,  32,  32,  32,  32, 
   32,  32,  32,  61,  32, 115, 105, 101, 118, 101,  44,  10,  10,  32,  32,  32, 
   32, 103, 101, 116,  95, 112, 114, 105, 109, 101,  32,  61,  32, 103, 101, 116, 
   95, 112, 114, 105, 109, 101,  44,  10,  10,  32,  32,  32,  32, 105, 110, 106, 
  101,  99, 116,  83, 116, 114, 101,  97, 109,  32,  61,  32, 102, 117, 110,  99, 
  116, 105, 111, 110,  40, 116,  41,  10,  32,  32,  32,  32,  32,  32,  32,  32, 
  109,  97, 107, 101,  95, 115, 116, 114, 101,  97, 109,  32,  61,  32,  97, 115, 
  115, 101, 114, 116,  40, 116,  46, 109,  97, 107, 101,  95, 115, 116, 114, 101, 
   97, 109,  95, 112, 108, 110,  41,  10,  32,  32,  32,  32,  32,  32,  32,  32, 
  115, 116, 114, 101,  97, 109,  95, 104, 101,  97, 100,  32,  61,  32,  97, 115, 
  115, 101, 114, 116,  40, 116,  46, 115, 116, 114, 101,  97, 109,  95, 104, 101, 
   97, 100,  95, 112, 108, 110,  41,  10,  32,  32,  32,  32,  32,  32,  32,  32, 
  115, 116, 114, 101,  97, 109,  95, 116,  97, 105, 108,  32,  61,  32,  97, 115, 
  115, 101, 114, 116,  40, 116,  46, 115, 116, 114, 101,  97, 109,  95, 116,  97, 
  105, 108,  95, 112, 108, 110,  41,  10,  32,  32,  32,  32,  32,  32,  32,  32, 
  115, 116, 114, 101,  97, 109,  95, 103, 101, 116,  32,  32,  61,  32,  97, 115, 
  115, 101, 114, 116,  40, 116,  46, 115, 116, 114, 101,  97, 109,  95, 103, 101, 
  116,  95, 112, 108, 110,  41,  10,  32,  32,  32,  32, 101, 110, 100,  44,  10, 
   10,  32,  32,  32,  32, 105, 110, 106, 101,  99, 116,  77,  97, 105, 110,  32, 
   61,  32, 102, 117, 110,  99, 116, 105, 111, 110,  40, 116,  41,  10,  32,  32, 
   32,  32,  32,  32,  32,  32,  99, 111, 117, 110, 116,  95, 102, 114, 111, 109, 
   32,  61,  32,  97, 115, 115, 101, 114, 116,  40, 116,  46,  99, 111, 117, 110, 
  116,  95, 102, 114, 111, 109,  95, 112, 108, 110,  41,  10,  32,  32,  32,  32, 
   32,  32,  32,  32, 115, 105, 102, 116,  32,  32,  32,  32,  32,  32,  32,  61, 
   32,  97, 115, 115, 101, 114, 116,  40, 116,  46, 115, 105, 102, 116,  95, 112, 
  108, 110,  41,  10,  32,  32,  32,  32,  32,  32,  32,  32, 115, 105, 101, 118, 
  101,  32,  32,  32,  32,  32,  32,  61,  32,  97, 115, 115, 101, 114, 116,  40, 
  116,  46, 115, 105, 101, 118, 101,  95, 112, 108, 110,  41,  10,  32,  32,  32, 
   32, 101, 110, 100,  44,  10, 125,  10,   0
};
 
#define LUA_AOT_LUAOPEN_NAME luaopen_benchmarks_streamSieve_injectLuaot
 
#include "luaot_footer.c"
