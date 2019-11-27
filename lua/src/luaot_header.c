//
// Most of what we need is copied verbatim from lvm.c
//

#include "lvm.c"

//
// These operations normally use `pc++` to skip metamethod calls in the
// fast case. We have to replace this with `goto LUA_AOT_SKIP1`
//

#undef  op_arithfI_aux
#define op_arithfI_aux(L,v1,imm,fop,tm,flip) {  \
  lua_Number nb;  \
  if (tonumberns(v1, nb)) {  \
    lua_Number fimm = cast_num(imm);  \
    setfltvalue(s2v(ra), fop(L, nb, fimm));  \
    goto LUA_AOT_SKIP1; \
  }}

#undef  op_arithI
#define op_arithI(L,iop,fop,tm,flip) {  \
  TValue *v1 = vRB(i);  \
  int imm = GETARG_sC(i);  \
  if (ttisinteger(v1)) {  \
    lua_Integer iv1 = ivalue(v1);  \
    setivalue(s2v(ra), iop(L, iv1, imm));  \
    goto LUA_AOT_SKIP1; \
  }  \
  else op_arithfI_aux(L, v1, imm, fop, tm, flip); }

#undef op_arithf_aux
#define op_arithf_aux(L,v1,v2,fop) {  \
  lua_Number n1; lua_Number n2;  \
  if (tonumberns(v1, n1) && tonumberns(v2, n2)) {  \
    setfltvalue(s2v(ra), fop(L, n1, n2));  \
    goto LUA_AOT_SKIP1; \
  }}

#undef  op_arith
#define op_arith(L,iop,fop) {  \
  TValue *v1 = vRB(i);  \
  TValue *v2 = vRC(i);  \
  if (ttisinteger(v1) && ttisinteger(v2)) {  \
    lua_Integer i1 = ivalue(v1); lua_Integer i2 = ivalue(v2);  \
    setivalue(s2v(ra), iop(L, i1, i2));  \
    goto LUA_AOT_SKIP1; \
  }  \
  else op_arithf_aux(L, v1, v2, fop); }

#undef  op_arithK
#define op_arithK(L,iop,fop,flip) {  \
  TValue *v1 = vRB(i);  \
  TValue *v2 = KC(i);  \
  if (ttisinteger(v1) && ttisinteger(v2)) {  \
    lua_Integer i1 = ivalue(v1); lua_Integer i2 = ivalue(v2);  \
    setivalue(s2v(ra), iop(L, i1, i2));  \
    goto LUA_AOT_SKIP1; \
  }  \
  else { \
    lua_Number n1; lua_Number n2;  \
    if (tonumberns(v1, n1) && tonumberns(v2, n2)) {  \
      setfltvalue(s2v(ra), fop(L, n1, n2));  \
      goto LUA_AOT_SKIP1; \
    }}}

#undef  op_arithfK
#define op_arithfK(L,fop) {  \
  TValue *v1 = vRB(i);  \
  TValue *v2 = KC(i);  \
  lua_Number n1; lua_Number n2;  \
  if (tonumberns(v1, n1) && tonumberns(v2, n2)) {  \
    setfltvalue(s2v(ra), fop(L, n1, n2));  \
    goto LUA_AOT_SKIP1; \
  }}

#undef  op_bitwiseK
#define op_bitwiseK(L,op) {  \
  TValue *v1 = vRB(i);  \
  TValue *v2 = KC(i);  \
  lua_Integer i1;  \
  lua_Integer i2 = ivalue(v2);  \
  if (tointegerns(v1, &i1)) {  \
    setivalue(s2v(ra), op(i1, i2));  \
    goto LUA_AOT_SKIP1; \
  }}

#undef  op_bitwise
#define op_bitwise(L,op) {  \
  TValue *v1 = vRB(i);  \
  TValue *v2 = vRC(i);  \
  lua_Integer i1; lua_Integer i2;  \
  if (tointegerns(v1, &i1) && tointegerns(v2, &i2)) {  \
    setivalue(s2v(ra), op(i1, i2));  \
    goto LUA_AOT_SKIP1; \
  }}


//
// These are the core macros for performing jumps.
// Obviously, we have to reimplement them.

#undef dojump

#undef  donextjump
#define donextjump(ci)	{ updatetrap(ci); goto LUA_AOT_NEXT_JUMP; }

#undef  docondjump
#define docondjump()	if (cond != GETARG_k(i)) goto LUA_AOT_SKIP1; else donextjump(ci);

//
// The program counter is now known statically at each program point.
//

#undef  savepc
#define savepc(L)	(ci->u.l.savedpc = LUA_AOT_PC)

//
// Our modified version of vmfetch(). Since instr and index are compile time
// constants, the C compiler should be able to optimize the code in many cases.
//

#undef  vmfetch
#define aot_vmfetch(instr)	{ \
  if (trap) {  /* stack reallocation or hooks? */ \
    trap = luaG_traceexec(L, LUA_AOT_PC - 1);  /* handle hooks */ \
    updatebase(ci);  /* correct stack */ \
  } \
  i = instr; \
  ra = RA(i); /* WARNING: any stack reallocation invalidates 'ra' */ \
}

#undef  vmdispatch
#undef  vmcase
#undef  vmbreak
