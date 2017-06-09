open preamble ml_translatorTheory cfTacticsLib set_sepTheory cfHeapsBaseTheory cfStoreTheory Satisfy

val _ = new_theory "cfLetAuto";

(* Rewrite rules for the int_of_num & operator*)
val INT_OF_NUM_ADD = Q.store_thm("INT_OF_NUM_ADD",
`!(x:num) (y:num).(&x) + &y = &(x+y)`, rw[] >> intLib.ARITH_TAC);
val INT_OF_NUM_TIMES = Q.store_thm("INT_OF_NUM_TIMES",
`!(x:num) (y:num).(&x) * &y = &(x*y)`, rw[] >> intLib.ARITH_TAC);
val INT_OF_NUM_LE = Q.store_thm("INT_OF_NUM_LE",
`!(x:num) (y:num). (&x <= &y) = (x <= y)`, rw[]);
val INT_OF_NUM_LESS = Q.store_thm("INT_OF_NUM_LESS",
`!(x:num) (y:num). (&x < &y) = (x < y)`, rw[]);
val INT_OF_NUM_GE = Q.store_thm("INT_OF_NUM_GE",
`!(x:num) (y:num). (&x >= &y) = (x >= y)`, rw[] >> intLib.ARITH_TAC);
val INT_OF_NUM_GREAT = Q.store_thm("INT_OF_NUM_GREAT",
`!(x:num) (y:num). (&x > &y) = (x > y)`, rw[] >> intLib.ARITH_TAC);
val INT_OF_NUM_EQ = Q.store_thm("INT_OF_NUM_EQ",
`!(x:num) (y:num). (&x = &y) = (x = y)`, rw[] >> intLib.ARITH_TAC);
val INT_OF_NUM_SUBS = Q.store_thm("INT_OF_NUM_SUBS",
`!(x:num) (y:num) (z:num). (&x - &y = &z) <=> (x - y = z) /\ y <= x`,
rw[] >> intLib.ARITH_TAC);
val INT_OF_NUM_SUBS_2 = Q.store_thm("INT_OF_NUM_SUBS_2",
`!(x:num) (y:num). y <= x ==> (&x - &y = &(x - y))`,
rw[] >> fs[int_arithTheory.INT_NUM_SUB]);

(* Predicate stating that a heap is valid *)
val VALID_HEAP_def =
    Define `VALID_HEAP s = ?(f : ffi ffi_proj) st. s = st2heap f st`;

(* Fundamental property of a valid heap used to handle pointers when extracting a frame from a heap condition - starts by a minor lemma *)
val PTR_MEM_LEM = Q.prove(`!s l xv H. (l ~~>> xv * H) s ==> Mem l xv IN s`,
rw[STAR_def, SPLIT_def, cell_def, one_def] >> fs[]);

val UNIQUE_PTRS = Q.store_thm("UNIQUE_PTRS",
`!s. VALID_HEAP s ==> !l xv xv' H H'. (l ~~>> xv * H) s /\ (l ~~>> xv' * H') s ==> xv' = xv`,
rw[VALID_HEAP_def] >>
fs[st2heap_def] >>
IMP_RES_TAC PTR_MEM_LEM >>
fs[UNION_DEF]
>-(IMP_RES_TAC store2heap_IN_unique_key)>>
IMP_RES_TAC Mem_NOT_IN_ffi2heap);

(* Fundamental property of a valid heap used to handle ffi components when extracting a frame from a heap condition *)
val NON_OVERLAP_FFI_PART = Q.store_thm("NON_OVERLAP_FFI_PART",
`!s. VALID_HEAP s ==>
!s1 u1 ns1 ts1 s2 u2 ns2 ts2. FFI_part s1 u1 ns1 ts1 IN s /\ FFI_part s2 u2 ns2 ts2 IN s /\ (?p. MEM p ns1 /\ MEM p ns2) ==>
s2 = s1 /\ u2 = u1 /\ ns2 = ns1 /\ ts2 = ts1`,
rpt (FIRST[GEN_TAC, DISCH_TAC]) >>
fs[VALID_HEAP_def, st2heap_def, UNION_DEF] >>
`FFI_part s1 u1 ns1 ts1 ∈ ffi2heap f st.ffi` by (rw[] >> fs[FFI_part_NOT_IN_store2heap]) >>
`FFI_part s2 u2 ns2 ts2 ∈ ffi2heap f st.ffi` by (rw[] >> fs[FFI_part_NOT_IN_store2heap]) >>
Cases_on `f` >>
Q.RENAME_TAC [`(q, r)`, `(proj, parts)`] >>
fs[ffi2heap_def] >>
Cases_on `parts_ok st.ffi (proj, parts)`
>-(
    fs[] >>
    fs[parts_ok_def] >>
    sg `ns2 = ns1`
    >-(
       `MEM ns1 (MAP FST parts)` by
       (
	   `?n. n < LENGTH parts /\ (ns1, u1) = EL n parts` by (IMP_RES_TAC MEM_EL >> SATISFY_TAC) >>
	   `FST (EL n parts) = ns1` by FIRST_ASSUM (fn x => fs[GSYM x, FST]) >>
	   `n < LENGTH (MAP FST parts)` by fs[LENGTH_MAP] >>
	   `EL n (MAP FST parts) = FST (EL n parts)` by fs[EL_MAP] >>
	   metis_tac[GSYM MEM_EL]
       ) >>
       `MEM ns2 (MAP FST parts)` by
       (
	   `?n. n < LENGTH parts /\ (ns2, u2) = EL n parts` by (IMP_RES_TAC MEM_EL >> SATISFY_TAC) >>
	   `FST (EL n parts) = ns2` by FIRST_ASSUM (fn x => fs[GSYM x, FST]) >>
	   `n < LENGTH (MAP FST parts)` by fs[LENGTH_MAP] >>
	   `EL n (MAP FST parts) = FST (EL n parts)` by fs[EL_MAP] >>
	   metis_tac[GSYM MEM_EL]
       ) >>
       metis_tac[cfTheory.ALL_DISTINCT_FLAT_MEM_IMP]
    ) >>
    (* Simplify the goal *)
    fs[] >>

    (* s2 = s1 *)
    `FLOOKUP (proj st.ffi.ffi_state) p = SOME s1` by metis_tac[] >>
    `FLOOKUP (proj st.ffi.ffi_state) p = SOME s2` by metis_tac[] >>
    fs[] >>

    (* u2 = u1 *)
    IMP_RES_TAC ALL_DISTINCT_FLAT_FST_IMP
) >>
fs[]);

(* A minor lemma *)
val FFI_PORT_IN_HEAP_LEM = Q.prove(
`! s u ns events H h. (one (FFI_part s u ns events) * H) h ==> FFI_part s u ns events IN h`,
rw[one_def, STAR_def, SPLIT_def, IN_DEF, UNION_DEF] >> rw[]);

(* Another fundamental theorem *)
val FRAME_UNIQUE_IO = Q.store_thm("FRAME_UNIQUE_IO",
`!s. VALID_HEAP s ==>
!s1 u1 ns1 s2 u2 ns2 H1 H2.
(IO s1 u1 ns1 * H1) s /\ (IO s2 u2 ns2 * H2) s ==> 
(?pn. MEM pn ns1 /\ MEM pn ns2) ==>
s2 = s1 /\ u2 = u1 /\ ns2 = ns1`,
rpt (FIRST[GEN_TAC, DISCH_TAC]) >>
fs[IO_def, SEP_CLAUSES, SEP_EXISTS_THM] >>
IMP_RES_TAC FFI_PORT_IN_HEAP_LEM >>
IMP_RES_TAC NON_OVERLAP_FFI_PART >>
fs[]);

(* Frame extraction theorems *)
val HCOND_EXTRACT = Q.store_thm("HCOND_EXTRACT",
`((&A * H) s <=> A /\ H s) /\ ((H * &A) s <=> H s /\ A) /\ ((H * &A * H') s <=> (H * H') s /\ A)`,
rw[] >-(fs[STAR_def, STAR_def, cond_def, SPLIT_def])
>-(fs[STAR_def, STAR_def, cond_def, SPLIT_def]) >>
fs[STAR_def, STAR_def, cond_def, SPLIT_def] >> EQ_TAC >-(rw [] >-(instantiate) >> rw[]) >> rw[]);

(* Unicity results for pointers *)
val solve_unique_refs = (rw[] >> qspec_then `s:heap` ASSUME_TAC UNIQUE_PTRS >>
    fs[REF_def, ARRAY_def, W8ARRAY_def, SEP_CLAUSES, SEP_EXISTS_THM] >>
    `!A H1 H2. (&A * H1 * H2) s <=> A /\ (H1 * H2) s` by metis_tac[HCOND_EXTRACT, STAR_COMM] >>
    POP_ASSUM (fn x => fs[x]) >> rw[] >> POP_ASSUM IMP_RES_TAC >> fs[]);

val UNIQUE_REFS = Q.store_thm("UNIQUE_REFS",
`!s r xv xv' H H'. VALID_HEAP s ==> (r ~~> xv * H) s /\ (r ~~> xv' * H') s ==> xv' = xv`,
solve_unique_refs);

val UNIQUE_ARRAYS = Q.store_thm("UNIQUE_ARRAYS",
`!s a av av' H H'. VALID_HEAP s ==> (ARRAY a av * H) s /\ (ARRAY a av' * H') s ==> av' = av`,
solve_unique_refs);

val UNIQUE_W8ARRAYS = Q.store_thm("UNIQUE_W8ARRAYS",
`!s a av av' H H'. VALID_HEAP s ==> (W8ARRAY a av * H) s /\ (W8ARRAY a av' * H') s ==> av' = av`,
solve_unique_refs);

(* Theorems and rewrites for REPLICATE and LIST_REL *)
val APPEND_LENGTH_INEQ = Q.store_thm("APPEND_LENGTH_INEQ",
`!l1 l2. LENGTH(l1) <= LENGTH(l1++l2) /\ LENGTH(l2) <= LENGTH(l1++l2)`,
Induct >-(strip_tac >> rw[]) >> rw[]);

val REPLICATE_APPEND_RIGHT = Q.prove(
`a++b = REPLICATE n x ==> b = REPLICATE (LENGTH b) x`,
strip_tac >>
`b = DROP (LENGTH a) (a++b)` by simp[GSYM DROP_LENGTH_APPEND] >>
`b = DROP (LENGTH a) (REPLICATE n x)` by POP_ASSUM (fn thm => metis_tac[thm]) >>
`b = REPLICATE (n - (LENGTH a)) x` by POP_ASSUM (fn thm => metis_tac[thm, DROP_REPLICATE]) >>
fs[LENGTH_REPLICATE]);

val REPLICATE_APPEND_LEFT = Q.prove(
`a++b = REPLICATE n x ==> a = REPLICATE (LENGTH a) x`,
strip_tac >> `b = REPLICATE (LENGTH b) x` by metis_tac[REPLICATE_APPEND_RIGHT] >>
`LENGTH b <= n` by metis_tac[APPEND_LENGTH_INEQ, LENGTH_REPLICATE] >>
`REPLICATE n x = REPLICATE (n-(LENGTH b)) x ++ REPLICATE (LENGTH b) x` by simp[REPLICATE_APPEND] >>
POP_ASSUM (fn x => fs[x]) >> POP_ASSUM (fn x => ALL_TAC) >>
`a ++ REPLICATE (LENGTH b) x = REPLICATE (n − LENGTH b) x ++ REPLICATE (LENGTH b) x` by metis_tac[] >>
fs[LENGTH_REPLICATE]);

val REPLICATE_APPEND_DECOMPOSE = Q.store_thm("REPLICATE_APPEND_DECOMPOSE",
`a ++ b = REPLICATE n x <=>
a = REPLICATE (LENGTH a) x /\ b = REPLICATE (LENGTH b) x /\ LENGTH a + LENGTH b = n`,
EQ_TAC >-(rw[] >-(metis_tac[REPLICATE_APPEND_LEFT]) >-(metis_tac[REPLICATE_APPEND_RIGHT]) >> metis_tac [LENGTH_REPLICATE, LENGTH_APPEND]) >> metis_tac[REPLICATE_APPEND]);

val REPLICATE_APPEND_DECOMPOSE_SYM = save_thm("REPLICATE_APPEND_DECOMPOSE_SYM",
CONV_RULE(PATH_CONV "lr" SYM_CONV) REPLICATE_APPEND_DECOMPOSE);

val REPLICATE_PLUS_ONE = Q.store_thm("REPLICATE_PLUS_ONE",
`REPLICATE (n + 1) x = x::REPLICATE n x`,
`n+1 = SUC n` by rw[] >> rw[REPLICATE]);

val LIST_REL_DECOMPOSE_RIGHT_recip = Q.prove(
`!R. LIST_REL R (a ++ b) x ==> LIST_REL R a (TAKE (LENGTH a) x) /\ LIST_REL R b (DROP (LENGTH a) x)`,
strip_tac >> strip_tac >>
`x = TAKE (LENGTH a) x ++ DROP (LENGTH a) x` by rw[TAKE_DROP] >>
`LENGTH (a ++ b) = LENGTH x` by (MATCH_MP_TAC LIST_REL_LENGTH >> rw[]) >>
POP_ASSUM (fn x => CONV_RULE (SIMP_CONV list_ss []) x |> ASSUME_TAC) >>
`LENGTH a <= LENGTH x` by bossLib.DECIDE_TAC >>
metis_tac[LENGTH_TAKE, LIST_REL_APPEND_IMP]);

val LIST_REL_DECOMPOSE_RIGHT_imp = Q.prove(
`!R. LIST_REL R a (TAKE (LENGTH a) x) /\ LIST_REL R b (DROP (LENGTH a) x) ==> LIST_REL R (a ++ b) x`,
rpt strip_tac >>
`x = TAKE (LENGTH a) x ++ DROP (LENGTH a) x` by rw[TAKE_DROP] >>
metis_tac[rich_listTheory.EVERY2_APPEND_suff]);

val LIST_REL_DECOMPOSE_RIGHT = Q.store_thm("LIST_REL_DECOMPOSE_RIGHT",
`!R. LIST_REL R (a ++ b) x <=> LIST_REL R a (TAKE (LENGTH a) x) /\ LIST_REL R b (DROP (LENGTH a) x)`,
strip_tac >> metis_tac[LIST_REL_DECOMPOSE_RIGHT_recip, LIST_REL_DECOMPOSE_RIGHT_imp]);

val LIST_REL_DECOMPOSE_LEFT_recip = Q.prove(
`!R. LIST_REL R x (a ++ b) ==> LIST_REL R (TAKE (LENGTH a) x) a /\ LIST_REL R (DROP (LENGTH a) x) b`,
strip_tac >> strip_tac >>
`x = TAKE (LENGTH a) x ++ DROP (LENGTH a) x` by rw[TAKE_DROP] >>
`LENGTH x = LENGTH (a ++ b)` by (MATCH_MP_TAC LIST_REL_LENGTH >> rw[]) >>
POP_ASSUM (fn x => CONV_RULE (SIMP_CONV list_ss []) x |> ASSUME_TAC) >>
`LENGTH a <= LENGTH x` by bossLib.DECIDE_TAC >>
metis_tac[LENGTH_TAKE, LIST_REL_APPEND_IMP]);

val LIST_REL_DECOMPOSE_LEFT_imp = Q.prove(
`!R. LIST_REL R (TAKE (LENGTH a) x) a /\ LIST_REL R (DROP (LENGTH a) x) b ==> LIST_REL R x (a ++ b)`,
rpt strip_tac >>
`x = TAKE (LENGTH a) x ++ DROP (LENGTH a) x` by rw[TAKE_DROP] >>
metis_tac[rich_listTheory.EVERY2_APPEND_suff]);

val LIST_REL_DECOMPOSE_LEFT = Q.store_thm("LIST_REL_DECOMPOSE_LEFT",
`!R. LIST_REL R x (a ++ b) <=> LIST_REL R (TAKE (LENGTH a) x) a /\ LIST_REL R (DROP (LENGTH a) x) b`,
strip_tac >> metis_tac[LIST_REL_DECOMPOSE_LEFT_recip, LIST_REL_DECOMPOSE_LEFT_imp]);

val HEAD_TAIL = Q.store_thm("HEAD_TAIL",
`l <> [] ==> HD l :: TL l = l`,
Cases_on `l:'a list` >> rw[listTheory.TL, listTheory.HD]);

val HEAD_TAIL_DECOMPOSE_RIGHT = Q.store_thm("HEAD_TAIL_DECOMPOSE_RIGHT",
`x::a = b <=> b <> [] /\ x = HD b /\ a = TL b`,
rw[] >> EQ_TAC
>-(Cases_on `b:'a list` >-(rw[]) >>  rw[listTheory.TL, listTheory.HD, HEAD_TAIL]) >>
rw[HEAD_TAIL]);

val HEAD_TAIL_DECOMPOSE_LEFT = Q.store_thm("HEAD_TAIL_DECOMPOSE_LEFT",
`b = x::a <=> b <> [] /\ x = HD b /\ a = TL b`,
rw[] >> EQ_TAC
>-(Cases_on `b:'a list` >-(rw[]) >>  rw[listTheory.TL, listTheory.HD, HEAD_TAIL]) >>
rw[HEAD_TAIL]);
	 
(* Theorems used as rewrites for the refinement invariants *)
fun eqtype_unicity_thm_tac x =
  let
      val assum = MP (SPEC ``abs:'a -> v -> bool`` EqualityType_def |> EQ_IMP_RULE |> fst) x
  in
      MP_TAC assum
  end;

val EQTYPE_UNICITY_R = Q.store_thm("EQTYPE_UNICITY_R",
`!abs x y1 y2. EqualityType abs ==> abs x y1 ==> (abs x y2 <=> y2 = y1)`,
rpt strip_tac >> FIRST_ASSUM eqtype_unicity_thm_tac >> metis_tac[]);

val EQTYPE_UNICITY_L = Q.store_thm("EQTYPE_UNICITY_L",
`!abs x1 x2 y. EqualityType abs ==> abs x1 y ==> (abs x2 y <=> x2 = x1)`,
rpt strip_tac >> FIRST_ASSUM eqtype_unicity_thm_tac >> metis_tac[]);

(* Theorems to use LIST_REL A "as a" refinement invariant *)
val InjectiveRel_def = Define `
InjectiveRel A = !x1 y1 x2 y2. A x1 y1 /\ A x2 y2 ==> (x1 = x2 <=> y1 = y2)`;

val EQTYPE_INJECTIVEREL = Q.prove(`EqualityType A ==> InjectiveRel A`,
rw[InjectiveRel_def, EqualityType_def]);

val LIST_REL_INJECTIVE_REL = Q.store_thm("LIST_REL_INJECTIVE_REL",
`!A. InjectiveRel A ==> InjectiveRel (LIST_REL A)`,
rpt strip_tac >> SIMP_TAC list_ss [InjectiveRel_def] >> Induct_on `x1`
>-(
    rpt strip_tac >>
    fs[LIST_REL_NIL] >>
    EQ_TAC >>
    rw[LIST_REL_NIL] >>
    fs[LIST_REL_NIL]
) >>
rpt strip_tac >> fs[LIST_REL_def] >>
Cases_on `x2` >-(fs[LIST_REL_NIL]) >>
Cases_on `y2` >-(fs[LIST_REL_NIL]) >>
rw[] >> fs[LIST_REL_def] >>
EQ_TAC >> (rw[] >-(metis_tac[InjectiveRel_def]) >> metis_tac[]));

val LIST_REL_INJECTIVE_EQTYPE = Q.store_thm("LIST_REL_INJECTIVE_EQTYPE",
`!A. EqualityType A ==> InjectiveRel (LIST_REL A)`,
metis_tac[EQTYPE_INJECTIVEREL, LIST_REL_INJECTIVE_REL]);

val LIST_REL_UNICITY_RIGHT = Q.store_thm("LIST_REL_UNICITY_RIGHT",
`EqualityType A ==> LIST_REL A a b ==> (LIST_REL A a b' <=> b' = b)`,
metis_tac[EQTYPE_INJECTIVEREL, LIST_REL_INJECTIVE_EQTYPE, InjectiveRel_def]);

val LIST_REL_UNICITY_LEFT = Q.store_thm("LIST_REL_UNICITY_LEFT",
`EqualityType A ==> LIST_REL A a b ==> (LIST_REL A a' b <=> a' = a)`,
metis_tac[EQTYPE_INJECTIVEREL, LIST_REL_INJECTIVE_EQTYPE, InjectiveRel_def]);

(* Some theorems for rewrite rules with the refinement invariants *)
val RECONSTRUCT_INT = Q.store_thm("RECONSTRUCT_INT", `v = (Litv (IntLit i)) <=> INT i v`, rw[INT_def]);
val RECONSTRUCT_NUM = Q.store_thm("RECONSTRUCT_NUM", `v = (Litv (IntLit (&n))) <=> NUM n v`, rw[NUM_def, INT_def]);
val RECONSTRUCT_BOOL = Q.store_thm("RECONSTRUCT_BOOL", `v = Boolv b <=> BOOL b v`, rw[BOOL_def]);

val NUM_INT_EQ = Q.store_thm("NUM_INT_EQ",
`(!x y v. INT x v ==> (NUM y v <=> x = &y)) /\
(!x y v. NUM y v ==> (INT x v <=> x = &y)) /\
(!x v w. INT (&x) v ==> (NUM x w <=> w = v)) /\
(!x v w. NUM x v ==> (INT (&x) w <=> w = v))`,
fs[INT_def, NUM_def] >> metis_tac[]);

(* Some rules used to simplify arithmetic equations (not happy with that: write a conversion instead? *)

val NUM_EQ_lem = Q.prove(`!(a1:num) (a2:num) (b:num). b <= a1 ==> b <= a2 ==> (a1 = a2 <=> a1 - b = a2 - b)`, rw[]);

val NUM_EQ_SIMP1 = Q.store_thm("NUM_EQ_SIMP1",
`a1 + (NUMERAL n1)*b = a2 + (NUMERAL n2)*b <=>
a1 + (NUMERAL n1 - (MIN (NUMERAL n1) (NUMERAL n2)))*b = a2 + (NUMERAL n2 - (MIN (NUMERAL n1) (NUMERAL n2)))*b`,
  rw[MIN_DEF]
>-(
   `b*NUMERAL n1 <= a1 + b*NUMERAL n1` by rw[] >>
   `b*NUMERAL n1 <= a2 + b*NUMERAL n2` by (
      rw[] >>
      `b*NUMERAL n2 <= a2 + b*NUMERAL n2` by rw[] >>
      `b*NUMERAL n1 <= b*NUMERAL n2` by rw[] >>
      bossLib.DECIDE_TAC
   ) >>
   qspecl_then [`a1 + b * NUMERAL n1`, `a2 + b * NUMERAL n2`, `b * NUMERAL n1`] assume_tac NUM_EQ_lem >>
   POP_ASSUM (fn x => rw[x]) >>
   `b * (NUMERAL n2 - NUMERAL n1) = b * NUMERAL n2 - b * NUMERAL n1` by rw[] >>
   POP_ASSUM (fn x => rw[x]) >>
   `b*NUMERAL n1 <= b* NUMERAL n2` by rw[] >>
   bossLib.DECIDE_TAC
) >>
  `b*NUMERAL n1 <= a2 + b*NUMERAL n1` by rw[] >>
  `b*NUMERAL n2 <= b*NUMERAL n1` by rw[] >>
  `b*NUMERAL n2 <= a1 + b*NUMERAL n1` by rw[] >>
  `b*NUMERAL n2 <= a2 + b*NUMERAL n2` by rw[] >>
  qspecl_then[`a1 + b * NUMERAL n1`, `a2 + b * NUMERAL n2`, `b * NUMERAL n2`]assume_tac NUM_EQ_lem >>
  POP_ASSUM (fn x => rw[x]));

val NUM_EQ_SIMP2 = Q.store_thm("NUM_EQ_SIMP2",
`(NUMERAL n1)*b + a1 = (NUMERAL n2)*b + a2 <=>
(NUMERAL n1 - (MIN (NUMERAL n1) (NUMERAL n2)))*b + a1 = (NUMERAL n2 - (MIN (NUMERAL n1) (NUMERAL n2)))*b + a2`,
rw[CONV_RULE (SIMP_CONV arith_ss []) NUM_EQ_SIMP1]);

val NUM_EQ_SIMP3 = Q.store_thm("NUM_EQ_SIMP3",
`a1 + (NUMERAL n1)*b = (NUMERAL n2)*b + a2 <=>
a1 + (NUMERAL n1 - (MIN (NUMERAL n1) (NUMERAL n2)))*b = (NUMERAL n2 - (MIN (NUMERAL n1) (NUMERAL n2)))*b + a2`,
rw[CONV_RULE (SIMP_CONV arith_ss []) NUM_EQ_SIMP1]);

val NUM_EQ_SIMP4 = Q.store_thm("NUM_EQ_SIMP4",
`(NUMERAL n1)*b + a1 = a2 + (NUMERAL n2)*b <=>
(NUMERAL n1 - (MIN (NUMERAL n1) (NUMERAL n2)))*b + a1 = (NUMERAL n2 - (MIN (NUMERAL n1) (NUMERAL n2)))*b + a2`,
rw[CONV_RULE (SIMP_CONV arith_ss []) NUM_EQ_SIMP1]);

val NUM_EQ_SIMP5 = Q.store_thm("NUM_EQ_SIMP5",
`a1 + b = a2 + (NUMERAL n2)*b <=>
a1 + (1 - (MIN 1 (NUMERAL n2)))*b = a2 + (NUMERAL n2 - (MIN 1 (NUMERAL n2)))*b`,
`a1 + b = a1 + 1*b` by rw[] >>
POP_ASSUM (fn x => PURE_REWRITE_TAC [x]) >>
metis_tac[NUM_EQ_SIMP1]);

val NUM_EQ_SIMP6 = Q.store_thm("NUM_EQ_SIMP6",
`a1 + (NUMERAL n1)*b = a2 + b <=>
a1 + (NUMERAL n1 - (MIN 1 (NUMERAL n1)))*b = a2 + (1 - (MIN 1 (NUMERAL n1)))*b`,
`a2 + b = a2 + 1*b` by rw[] >>
POP_ASSUM (fn x => PURE_REWRITE_TAC [x]) >>
metis_tac[NUM_EQ_SIMP1]);

val NUM_EQ_SIMP7 = Q.store_thm("NUM_EQ_SIMP7",
`b + a1 = (NUMERAL n2)*b + a2 <=>
(1 - (MIN 1 (NUMERAL n2)))*b + a1 = (NUMERAL n2 - (MIN 1 (NUMERAL n2)))*b + a2`,
rw[CONV_RULE (SIMP_CONV arith_ss []) NUM_EQ_SIMP5]);

val NUM_EQ_SIMP8 = Q.store_thm("NUM_EQ_SIMP8",
`(NUMERAL n1)*b + a1 = b + a2 <=>
(NUMERAL n1 - (MIN 1 (NUMERAL n1)))*b + a1 = (1 - (MIN 1 (NUMERAL n1)))*b + a2`,
rw[CONV_RULE (SIMP_CONV arith_ss []) NUM_EQ_SIMP6]);

val NUM_EQ_SIMP9 = Q.store_thm("NUM_EQ_SIMP9",
`a1 + b = (NUMERAL n2)*b + a2 <=>
a1 + (1 - (MIN 1 (NUMERAL n2)))*b = (NUMERAL n2 - (MIN 1 (NUMERAL n2)))*b + a2`,
rw[CONV_RULE (SIMP_CONV arith_ss []) NUM_EQ_SIMP5]);

val NUM_EQ_SIMP10 = Q.store_thm("NUM_EQ_SIMP10",
`b + a1 = a2 + (NUMERAL n2)*b <=>
(1 - (MIN 1 (NUMERAL n2)))*b + a1 = a2 + (NUMERAL n2 - (MIN 1 (NUMERAL n2)))*b`,
rw[CONV_RULE (SIMP_CONV arith_ss []) NUM_EQ_SIMP5]);

val NUM_EQ_SIMP11 = Q.store_thm("NUM_EQ_SIMP11",
`a1 + (NUMERAL n1)*b = b + a2 <=>
a1 + (NUMERAL n1 - (MIN 1 (NUMERAL n1)))*b = (1 - (MIN 1 (NUMERAL n1)))*b + a2`,
rw[CONV_RULE (SIMP_CONV arith_ss []) NUM_EQ_SIMP6]);

val NUM_EQ_SIMP12 = Q.store_thm("NUM_EQ_SIMP12",
`(NUMERAL n1)*b + a1 = a2 + b <=>
(NUMERAL n1 - (MIN 1 (NUMERAL n1)))*b + a1 = a2 + (1 - (MIN 1 (NUMERAL n1)))*b`,
rw[CONV_RULE (SIMP_CONV arith_ss []) NUM_EQ_SIMP6]);

val _ = export_theory();