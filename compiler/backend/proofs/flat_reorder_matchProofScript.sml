open preamble flat_reorder_matchTheory flatSemTheory flatPropsTheory

val _ = new_theory "flat_reorder_matchProof";

val _ = temp_bring_to_front_overload
          "compile"
          {Name = "compile", Thy = "flat_reorder_match"};

val list_result_map_result = Q.store_thm("list_result_map_result",
  `list_result (map_result f g r) = map_result (MAP f) g (list_result r)`,
  Cases_on`r` \\ EVAL_TAC);

val MAP_FST_MAP_triple = Q.store_thm ("MAP_FST_MAP_triple",
  `! a b c y l. (MAP FST (MAP (\(a,b,c). a, b, (y c)) l)) = (MAP FST l)`,
  Induct_on `l` \\ fs [] \\ rw []
  \\ pairarg_tac \\ fs [])

val ALOOKUP_MAP3 = Q.store_thm("ALOOKUP_MAP3",
  `ALOOKUP (MAP (λ(a,b,c). (a,b, f c)) ls) =
   OPTION_MAP (λ(b,c). (b, f c)) o (ALOOKUP ls)`,
  qmatch_goalsub_abbrev_tac`OPTION_MAP g o _`
  \\ Q.ISPECL_THEN[`g`,`ls`](mp_tac o GSYM) ALOOKUP_MAP
  \\ simp[Abbr`g`,LAMBDA_PROD]);

val _ = temp_overload_on ("None",``NONE``)
val _ = temp_overload_on ("Some",``SOME``)
val _ = temp_overload_on ("Length",``LENGTH``)

val BAG_DISJOINT_SYM = Q.store_thm("BAG_DISJOINT_SYM",
  `BAG_DISJOINT b1 b2 ⇔ BAG_DISJOINT b2 b1`,
  rw[BAG_DISJOINT,DISJOINT_SYM]);

val BAG_ALL_DISTINCT_SUB = Q.store_thm("BAG_ALL_DISTINCT_SUB",
  `BAG_ALL_DISTINCT b2 ∧ b1 ≤ b2 ⇒ BAG_ALL_DISTINCT b1`,
  rw[BAG_ALL_DISTINCT,SUB_BAG,BAG_INN]
  \\ spose_not_then strip_assume_tac
  \\ fs[NOT_LESS_EQUAL,GREATER_EQ]
  \\ first_x_assum(qspecl_then[`e`,`2`]mp_tac)
  \\ simp[NOT_LESS_EQUAL]
  \\ first_x_assum(qspec_then`e`mp_tac)
  \\ simp[]);

val BAG_OF_LIST_def = Define`
  (BAG_OF_LIST [] = {||}) ∧
  (BAG_OF_LIST (x::xs) = BAG_INSERT x (BAG_OF_LIST xs))`;
val _ = export_rewrites["BAG_OF_LIST_def"];

val BAG_OF_LIST_empty = Q.store_thm("BAG_OF_LIST_empty[simp]",
  `(BAG_OF_LIST l = {||} ⇔ (l = []))`,
  Cases_on`l` \\ rw[]);

val BAG_INSERT_BAG_UNION = Q.store_thm("BAG_INSERT_BAG_UNION",
  `BAG_INSERT x (BAG_UNION b1 b2) = BAG_UNION (BAG_INSERT x b1) b2`,
  rw[BAG_INSERT_UNION,ASSOC_BAG_UNION]);

val BAG_OF_LIST_APPEND = Q.store_thm("BAG_OF_LIST_APPEND",
  `∀l1 l2. BAG_OF_LIST (l1 ++ l2) = BAG_UNION (BAG_OF_LIST l1) (BAG_OF_LIST l2)`,
  Induct \\ simp[BAG_INSERT_BAG_UNION]);

(* -- *)

val s = ``s:'ffi flatSem$state``;

(* value transformation *)

val MEM_size_mono = Q.store_thm("MEM_size_mono",
  `!a b. (MEM a b) ==> ((v_size a) < 1 + v3_size b)`,
  Induct_on `b` \\ rw [v_size_def] \\ res_tac \\ rw [])

val MEM_size_mono_v1_size = Q.store_thm("MEM_size_mono_v1_size",
  `! a v env. MEM (a,v) env ==> v_size v  < 1 + v1_size env`,
  Induct_on `env` \\ rw[] \\ rw [v_size_def] \\ res_tac \\ rw [])

val compile_v_def = tDefine "compile_v" `
  (compile_v (Litv l) = Litv l) /\
  (compile_v (Conv n vs) = Conv n (MAP compile_v vs)) /\
  (compile_v (Closure env name e) = Closure (MAP (\(a, v). (a, compile_v v) ) env) name (HD (compile [e]))) /\
  (compile_v (Recclosure env funs name) = Recclosure (MAP (\(a, v). (a, compile_v v) ) env) (MAP (\(a, b, e). (a, b, HD(compile [e]))) funs) name) /\
  (compile_v (Loc n) = Loc n) /\
  (compile_v (Vectorv vs) = Vectorv (MAP compile_v vs)) `
  (
    WF_REL_TAC `measure v_size`
    \\ rw []
    \\ imp_res_tac MEM_size_mono_v1_size
    \\ imp_res_tac MEM_size_mono
    \\ rw []
  )

val _ = export_rewrites ["compile_v_def"];

val _ = overload_on ("compile_env", ``MAP \(tn, v). (tn, compile_v v)``);

val ALOOKUP_compile_env = Q.store_thm ("ALOOKUP_compile_env",
  `! env q x.
      (ALOOKUP (compile_env env) q) = OPTION_MAP compile_v (ALOOKUP env q)`,
  Induct \\ rw []
  \\ pairarg_tac
  \\ fs []
  \\ rw [])

val compile_store_v_def = Define `
    (compile_store_v (Refv v) = Refv (compile_v v)) /\
    (compile_store_v (W8array l) = W8array l) /\
    (compile_store_v (Varray vs) = Varray (MAP compile_v vs))`

val compile_state_def = Define `
    compile_state (^s) =
    <| clock := s.clock;
       refs := MAP compile_store_v s.refs;
       ffi := s.ffi;
       globals := MAP (OPTION_MAP compile_v) s.globals
    |>`;

val dec_clock_compile_state = Q.store_thm("dec_clock_compile_state",
  `dec_clock (compile_state s) = compile_state (dec_clock s)`,
  EVAL_TAC);

val compile_state_with_clock = Q.store_thm("compile_state_with_clock",
  `compile_state st with clock := k = compile_state (st with clock := k)`,
  EVAL_TAC);

val compile_state_simps = save_thm ("compile_state_simps", LIST_CONJ
    [EVAL ``(compile_state s).globals``,
     EVAL ``(compile_state s).clock``,
     EVAL ``(compile_state s).ffi``,
     EVAL ``(compile_state s).refs``]);

val _ = export_rewrites ["compile_state_simps"];

(* syntactic properties of the compiler *)

val isPcon_isPvar = Q.store_thm("isPcon_isPvar",
  `∀x. isPcon x ==> ¬isPvar x`,
  Cases \\ rw[isPcon_def,isPvar_def]);

val is_const_con_thm = Q.store_thm("is_const_con_thm",
  `is_const_con x ⇔ ∃t. x = Pcon (SOME t) []`,
  Cases_on`x` \\ EVAL_TAC \\ rw[]
  \\ rename1`Pcon t l` \\ Cases_on`t` \\ EVAL_TAC \\ rw[]);

val isPcon_thm = Q.store_thm("is_Pcon_thm",
  `isPcon x ⇔ ∃t l. x = Pcon (SOME t) l`,
  Cases_on`x` \\ EVAL_TAC \\ rw[]
  \\ rename1`Pcon t l` \\ Cases_on`t` \\ EVAL_TAC \\ rw[EXISTS_THM]);

val is_const_con_is_Pcon = Q.store_thm("is_const_con_is_Pcon",
  `is_const_con x ==> isPcon x`,
  rw[is_const_con_thm,isPcon_thm]);

val same_con_is_const_con = Q.store_thm("same_con_is_const_con",
  `same_con x y ⇒ is_const_con x ∧ is_const_con y`,
  Cases_on`x` \\ Cases_on`y` \\ simp[]
  \\ rename1`same_con (Pcon o1 _) (Pcon o2 _)`
  \\ Cases_on`o1` \\ Cases_on`o2` \\ simp[]
  \\ Cases_on`l` \\ Cases_on`l'` \\ simp[]);

val is_const_con_pat_bindings_empty = Q.store_thm("is_const_con_pat_bindings_empty",
    `is_const_con x ==> pat_bindings x a = a`,
    rw [is_const_con_thm] \\ EVAL_TAC)

val compile_append = Q.store_thm ("compile_append",
  `! x h. compile (x ++ h) = (compile x) ++ (compile h)`,
  Induct_on `x` \\ fs [] \\ rw [Once compile_cons]
  \\ qspec_then `h` strip_assume_tac compile_sing \\ fs []
  \\ rw [Once compile_cons])

val compile_reverse = Q.store_thm ("compile_reverse",
  `! x. REVERSE (compile x) = compile (REVERSE x)`,
  Induct \\ fs [] \\ rw [Once compile_cons]
  \\ qspec_then `h` strip_assume_tac compile_sing \\ fs []
  \\ rw [EQ_SYM_EQ, REVERSE_DEF, compile_append]);

(* alternative characterisation of pattern matching *)

val find_match_def = Define`
    find_match env s v [] = No_match /\
    find_match env s v (pe::pes) =
        if ALL_DISTINCT (pat_bindings (FST pe) []) then
            case pmatch env s (FST pe) v [] of
            | Match env' => Match (env', SND pe)
            | Match_type_error => Match_type_error
            | _ => find_match env s v pes
        else Match_type_error `

val evaluate_match_find_match_none = Q.store_thm ("evaluate_match_find_match_none",
  `env.exh_pat ∧ (!r. find_match env ^s.refs v pes ≠ Match r) ==>
          evaluate_match env s v pes errv = (s, Rerr (Rabort Rtype_error))`,
  Induct_on `pes`
  \\ fs [find_match_def, evaluate_def]
  \\ Cases
  \\ fs [evaluate_def]
  \\ IF_CASES_TAC \\ fs[]
  \\ TOP_CASE_TAC
  \\ rw [])

val evaluate_match_find_match_some = Q.store_thm ("evaluate_match_find_match_some",
  ` find_match env s.refs v pes = Match (env',e) ==>
      evaluate_match env s v pes errv = evaluate (env with v := env' ++ env.v) s [e] `,
  Induct_on `pes`
  \\ fs [find_match_def,evaluate_def]
  \\ Cases
  \\ fs [evaluate_def]
  \\ TOP_CASE_TAC
  \\ CASE_TAC
  \\ rw[])

(* reordering operations are allowed *)

val pmatch_same_match = Q.store_thm("pmatch_same_match",
  `pmatch env refs c1 v [] = Match a /\ is_const_con c1 /\
   pmatch env refs c2 v [] = Match b /\ ~isPvar c2
      ==> same_con c1 c2`,
  rw[is_const_con_thm]
  \\ Cases_on`v` \\ fs[pmatch_def]
  \\ rename1`Conv o1` \\ Cases_on`o1` \\ fs[pmatch_def]
  \\ Cases_on`c2` \\ fs[pmatch_def]
  \\ rename1`same_con _ (Pcon o1 _)`
  \\ Cases_on`o1` \\ fs[pmatch_def]
  \\ fs[bool_case_eq,same_ctor_def] \\ rw[] \\ rfs[pmatch_def]
  \\ fs[FST_EQ_EQUIV] \\ rw[]
  \\ pop_assum mp_tac \\ rw[] \\ fs[]
  \\ Cases_on`x` \\ fs[]);

val pmatch_match_match = Q.store_thm("pmatch_match_match",
  `¬env.check_ctor ∧
   is_const_con x /\ isPcon y /\ pmatch env refs x v [] = Match_type_error ==>
   pmatch env refs y v [] = Match_type_error`,
  rw[is_const_con_thm,isPcon_thm]
  \\ Cases_on`v` \\ fs[pmatch_def]
  \\ rename1`Conv tt _` \\ Cases_on`tt`
  \\ fs[pmatch_def,semanticPrimitivesTheory.same_ctor_def]
  \\ pop_assum mp_tac \\ simp[bool_case_eq]);

val pmatch_no_match = Q.store_thm("pmatch_no_match",
  `¬env.check_ctor ∧ pmatch env refs x v [] = No_match ∧ same_con y x ⇒
   pmatch env refs y v [] = No_match`,
  Cases_on`x` \\ Cases_on`y` \\ fs[pmatch_def]
  \\ rename1`same_con (Pcon o1 _) (Pcon o2 _)`
  \\ Cases_on`o1` \\ Cases_on`o2` \\ fs[pmatch_def]
  \\ Cases_on`l` \\ Cases_on`l'` \\ fs[pmatch_def]
  \\ Cases_on`x` \\ Cases_on`x'` \\ fs[pmatch_def]
  \\ Cases_on`v` \\ fs[pmatch_def]
  \\ Cases_on`o'` \\ fs[pmatch_def]
  \\ Cases_on`x`
  \\ rw[] \\ fs[same_ctor_def,ctor_same_type_def]
  \\ rw[] \\ rfs[]);

val find_match_drop_no_match = Q.store_thm ("find_match_drop_no_match",
    `! a b. pmatch env s (FST b) v [] = No_match /\ (is_const_con (FST b)) ==>
     ((find_match env s v ( a++ [b] ++c)) = find_match env s v (a++c))`,
     Induct
     \\ rw [find_match_def, is_const_con_pat_bindings_empty]
)

val find_match_may_drop_dup = Q.store_thm ("find_match_may_drop_dup",
    `¬env.check_ctor ⇒
     ! a b. ((is_const_con (FST b)) /\ (EXISTS (same_con (FST b) o FST) a)) ==>
     ((find_match env s v ( a++ [b] ++c)) = find_match env s v (a++c))`,
     strip_tac \\ Induct
     \\ rw [find_match_def]
     \\ CASE_TAC \\ fs[]
     \\ match_mp_tac find_match_drop_no_match \\ fs[]
     \\ match_mp_tac (GEN_ALL pmatch_no_match) \\ fs[]
     \\ asm_exists_tac \\ fs[]
);

val find_match_may_reord = Q.store_thm("find_match_may_reord",
    `¬env.check_ctor ⇒
     ! a b. is_const_con (FST b) /\ ¬(EXISTS (same_con (FST b) o FST) a)
            /\ EVERY isPcon (MAP FST a) /\
            find_match env s v (a ++ [b] ++ c) ≠ Match_type_error
            ==>
        find_match env s v (a ++ [b] ++ c) = find_match env s v (b::a++c) `,
    strip_tac \\
    Induct \\ fs []
    \\ rw [find_match_def]
    \\ every_case_tac \\ fs [find_match_def]
    >- ( imp_res_tac pmatch_match_match \\ fs [])
    >- ( imp_res_tac pmatch_match_match \\ fs [])
    >- (
        imp_res_tac isPcon_isPvar
        \\ imp_res_tac pmatch_same_match)
    >- (
      CCONTR_TAC \\ fs[EVERY_MAP] \\
      first_x_assum(qspec_then`b`mp_tac) \\ rw[]
      \\ fs[EVERY_MEM])
    >- (
      CCONTR_TAC \\ fs[]
      \\ fs[is_const_con_pat_bindings_empty] ))

val find_match_drop_after_pvar = Q.store_thm("find_match_drop_after_pvar",
    `! a. isPvar (FST b) ==>
        find_match env refs v (a ++ [b] ++ c) = find_match env refs v (a ++ [b])
    `,
    Induct \\ fs [find_match_def]
    \\ rw []
    \\ CASE_TAC
    \\ Cases_on `FST b` \\ fs [pmatch_def, isPvar_def]
    )

(* characterisation of reordering operations as rules *)

val (reord_rules,reord_ind,reord_cases) = Hol_reln`
  (isPvar (FST b) ==> reord (a ++ [b] ++ c) (a ++ [b])) /\
  (is_const_con (FST b) /\
   EXISTS (same_con (FST b) o FST) a ==>
   reord (a ++ [b] ++ c) (a ++ c)) /\
  (is_const_con (FST b) /\
   ¬EXISTS (same_con (FST b) o FST) a /\
   EVERY isPcon (MAP FST a) ==>
   reord (a ++ [b] ++ c) ([b] ++ a ++ c))`;

val const_cons_sep_reord = Q.store_thm("const_cons_sep_reord",
    `! a const_cons.
        const_cons_sep pes a const_cons = (const_cons', a') /\
        EVERY isPcon (MAP FST a) /\
        EVERY ($~ o is_const_con) (MAP FST a) /\
        EVERY is_const_con (MAP FST const_cons)
         ==>
        reord^* (const_cons ++ (REVERSE a) ++ pes) (const_cons' ++ (REVERSE a')) `,
    Induct_on `pes` \\ fs [] \\ rw [const_cons_sep_def]
    >- (
        rw []
        \\ match_mp_tac RTC_SUBSET
        \\ rw [reord_cases]
    )
    >- (
       rw [Once RTC_CASES1]
       \\ disj2_tac
       \\ fs []
       \\ first_x_assum drule \\ strip_tac
       \\ rfs []
       \\ HINT_EXISTS_TAC
       \\ rw [reord_cases]
       \\ METIS_TAC[EXISTS_APPEND]
    )
    >-(
      fs []
      \\ first_x_assum drule \\ strip_tac
      \\ rfs []
      \\ rw [Once RTC_CASES1]
      \\ disj2_tac
      \\ HINT_EXISTS_TAC
      \\ rw [reord_cases]
      \\ disj2_tac \\ disj2_tac
      \\ qexists_tac`const_cons ++ REVERSE a`
      \\ simp[MAP_REVERSE,EVERY_REVERSE]
      \\ fs[EVERY_MEM,MEM_MAP,PULL_EXISTS]
      \\ metis_tac[is_const_con_is_Pcon,same_con_is_const_con] )
    >- (
      first_x_assum drule \\ strip_tac
      \\ rfs[]
      \\ metis_tac[CONS_APPEND,APPEND_ASSOC] )
    >- (
      rw[REVERSE_APPEND] ))

val const_cons_fst_reord = Q.store_thm("const_cons_fst_reord",
    `reord^* pes (const_cons_fst pes)`,
    fs [const_cons_fst_def]
    \\ pairarg_tac
    \\ fs []
    \\ imp_res_tac const_cons_sep_reord \\ fs[])

val find_match_preserved_reord = Q.store_thm("find_match_preserved_reord",
    `¬env.check_ctor ⇒
     ! pes pes'. reord pes pes' ==>
        find_match env refs v pes <> Match_type_error ==>
            find_match env refs v pes = find_match env refs v pes'`,
    strip_tac \\
    ho_match_mp_tac reord_ind
    \\ strip_tac
    >-(
        METIS_TAC [find_match_drop_after_pvar]
    )
    \\ strip_tac
    >- (
        METIS_TAC [find_match_may_drop_dup]
    )
    \\ METIS_TAC [find_match_may_reord, APPEND_ASSOC, CONS_APPEND]
)

val find_match_preserved_reord_RTC = Q.store_thm("find_match_preserved_reord_RTC",
    `¬env.check_ctor ⇒ ! pes pes'. reord^* pes pes' ==>
        find_match env refs v pes <> Match_type_error ==>
            find_match env refs v pes = find_match env refs v pes'`,
    strip_tac \\ ho_match_mp_tac RTC_INDUCT
    \\ METIS_TAC [find_match_preserved_reord]
    )

(* main lemma: find_match semantics preserved by compilation *)

val const_cons_fst_find_match = Q.store_thm("const_cons_fst_find_match",
    `¬env.check_ctor ∧ find_match env refs v pes <> Match_type_error ==>
        find_match env refs v pes = find_match env refs v (const_cons_fst pes)`,
    METIS_TAC [find_match_preserved_reord_RTC, const_cons_fst_reord])

(* semantic auxiliaries respect transformation of values *)

val pmatch_compile = Q.store_thm("pmatch_compile",
  `(!env refs p err_v acc.
     pmatch (env with v := compile_env env.v)
            (MAP compile_store_v refs) p
            (compile_v err_v) (compile_env acc) =
     map_match (compile_env) (pmatch env refs p err_v acc)) /\
   (! env refs ps vs acc.
      pmatch_list (env with v := compile_env env.v)
                  (MAP compile_store_v refs) ps
                  (MAP compile_v vs) (compile_env acc) =
      map_match (compile_env) (pmatch_list env refs ps vs acc)) `,
  ho_match_mp_tac pmatch_ind \\ rw [pmatch_def]
  >- (fs [ETA_AX])
  >- (fs [ETA_AX])
  >- (
    fs [semanticPrimitivesTheory.store_lookup_def]
    \\ rw [EL_MAP]
    \\ match_mp_tac EQ_SYM
    \\ CASE_TAC \\ fs[compile_store_v_def]
  )
  >- (
    every_case_tac \\ fs []
    \\ rw []
  ))

val pmatch_compile_nil = pmatch_compile |> CONJUNCT1
    |> SPEC_ALL
    |> Q.GEN`acc`
    |> Q.SPEC`[]`
    |> SIMP_RULE (srw_ss())[]

val find_match_compile = Q.store_thm("find_match_compile",
  `find_match (env with v := compile_env env.v)
              (MAP compile_store_v refs)
              (compile_v v) (MAP (I ## f) pes) =
   map_match (compile_env ## f) (find_match env refs v pes)`,
   Induct_on `pes`
   \\ fs [find_match_def]
   \\ rw []
   \\ fs [pmatch_compile_nil]
   \\ every_case_tac \\ fs [])

val find_match_imp_compile = Q.store_thm("find_match_imp_compile",
  `find_match env s.refs v pes = Match (env',e) ==>
   find_match (env with v := compile_env env.v)
              (compile_state s).refs (compile_v v)
       (MAP (\(p,e). (p,HD(compile[e]))) pes) =
           Match (compile_env env', HD(compile[e]))`,
  strip_tac \\
  (Q.GENL[`f`,`refs`,`v`,`pes`]find_match_compile
   |> Q.ISPECL_THEN[`\e. HD(compile[e])`,`s.refs`,`v`,`pes`]mp_tac) \\
  simp[] \\
  disch_then(SUBST1_TAC o SYM) \\
  rpt(AP_TERM_TAC ORELSE AP_THM_TAC) \\
  simp[FUN_EQ_THM,FORALL_PROD]);

val do_opapp_compile = Q.store_thm("do_opapp_compile[simp]",
  `do_opapp (MAP compile_v as) =
    OPTION_MAP (λ(env,e). (compile_env env, HD (compile [e]))) (do_opapp as)`,
  rw[do_opapp_def]
  \\ every_case_tac
  \\ fs[semanticPrimitivesPropsTheory.find_recfun_ALOOKUP,build_rec_env_merge]
  \\ rw[] \\ fsrw_tac[ETA_ss][ALOOKUP_MAP3,MAP_MAP_o,o_DEF,UNCURRY]);

val do_eq_compile = Q.store_thm("do_eq_compile[simp]",
  `(∀v1 v2. do_eq (compile_v v1) (compile_v v2) = do_eq v1 v2) ∧
   (∀v1 v2. do_eq_list (MAP compile_v v1) (MAP compile_v v2) = do_eq_list v1 v2)`,
  ho_match_mp_tac do_eq_ind
  \\ srw_tac[ETA_ss][do_eq_def]
  \\ every_case_tac \\ fs[]);

val store_v_same_type_compile = Q.store_thm("store_v_same_type_compile[simp]",
  `(store_v_same_type (compile_store_v v1) v2 ⇔ store_v_same_type v1 v2) ∧
   (store_v_same_type v1 (compile_store_v v2) ⇔ store_v_same_type v1 v2) ∧
   (store_v_same_type (Refv (compile_v x1)) v2 ⇔ store_v_same_type (Refv x1) v2) ∧
   (store_v_same_type v1 (Refv (compile_v x2)) ⇔ store_v_same_type v1 (Refv x2))`,
  Cases_on`v1` \\ Cases_on`v2` \\ EVAL_TAC);

val v_to_char_list_compile = Q.store_thm("v_to_char_list_compile[simp]",
  `∀ls. v_to_char_list (compile_v ls) = v_to_char_list ls`,
  ho_match_mp_tac v_to_char_list_ind \\ rw[v_to_char_list_def]);

val v_to_list_compile = Q.store_thm("v_to_list_compile[simp]",
  `∀v. v_to_list (compile_v v) = OPTION_MAP (MAP compile_v) (v_to_list v)`,
  ho_match_mp_tac v_to_list_ind \\ rw[v_to_list_def]
  \\ every_case_tac \\ fs[]);

val vs_to_strings_compile = Q.store_thm("vs_to_strings_compile[simp]",
  `∀vs. vs_to_string (MAP compile_v vs) = vs_to_string vs`,
  ho_match_mp_tac vs_to_string_ind \\ rw[vs_to_string_def]);

val list_to_v_compile_APPEND = Q.store_thm("list_to_v_compile_APPEND",
  `!xs ys.
     list_to_v (MAP compile_v xs) = compile_v (list_to_v xs) /\
     list_to_v (MAP compile_v ys) = compile_v (list_to_v ys) ==>
       list_to_v (MAP compile_v (xs ++ ys)) =
       compile_v (list_to_v (xs ++ ys))`,
  Induct \\ rw [compile_v_def, list_to_v_def] \\ rfs []);

val list_to_v_compile = Q.store_thm("list_to_v_compile",
  `!xs. list_to_v (MAP compile_v xs) = compile_v (list_to_v xs)`,
  Induct \\ rw [compile_v_def, list_to_v_def]);

val do_app_compile = Q.store_thm("do_app_compile[simp]",
  `do_app cc (compile_state s) op (MAP compile_v as) =
   OPTION_MAP (λ(s,r). (compile_state s, map_result compile_v compile_v r))
              (do_app cc s op as)`,
  Cases_on `op = ListAppend`
  >-
   (Cases_on `do_app cc s op as` \\ fs [] \\ rveq
    \\ pop_assum mp_tac
    \\ simp [do_app_def] \\ fs [case_eq_thms] \\ rw []
    \\ pairarg_tac \\ fs [] \\ rveq
    \\ metis_tac [list_to_v_compile, list_to_v_compile_APPEND, MAP_APPEND])
  \\ Cases_on `do_app cc s op as` \\ Cases_on `op`
  \\ pop_assum mp_tac
  \\ fs[do_app_def,
        semanticPrimitivesTheory.store_assign_def,
        semanticPrimitivesTheory.store_alloc_def,
        semanticPrimitivesTheory.store_lookup_def,
        EL_MAP,compile_store_v_def]
  \\ rpt (PURE_TOP_CASE_TAC \\ fs [])
  \\ rfs[EL_MAP,semanticPrimitivesTheory.store_v_same_type_def]
  \\ every_case_tac \\ fs [compile_store_v_def]
  \\ rw [EL_MAP, METIS_PROVE [] ``a \/ b <=> ~a ==> b``, ELIM_UNCURRY]
  \\ fs [] \\ EVAL_TAC
  \\ fs [LUPDATE_MAP,compile_store_v_def,map_replicate, IS_SOME_EXISTS]);

(* main results *)

val compile_evaluate = Q.store_thm("compile_evaluate",
  `(!env ^s es s1 r1.
     evaluate env s es = (s1, r1) /\
     r1 <> Rerr (Rabort Rtype_error) /\
     env.exh_pat /\
     ~env.check_ctor
     ==>
     evaluate (env with v := compile_env env.v)
              (compile_state s)
              (compile es) =
       (compile_state s1, map_result (MAP compile_v) compile_v r1)) /\
   (!env ^s v pes err_v s1 r1.
     evaluate_match env ^s v pes err_v = (s1,r1) /\
     r1 <> Rerr (Rabort Rtype_error) /\
     env.exh_pat /\
     ~env.check_ctor
     ==>
     evaluate_match (env with v := compile_env env.v)
                    (compile_state s)
                    (compile_v v)
                    (MAP (\(p,e). (p,HD(compile[e]))) pes)
                    (compile_v err_v) =
       (compile_state s1, map_result (MAP compile_v) compile_v r1))`,
  ho_match_mp_tac evaluate_ind
  \\ rw [compile_def] \\ fs [evaluate_def] \\ rw []
  \\ fs [MAP_FST_MAP_triple]
  >-
   (fs [case_eq_thms, pair_case_eq] \\ rw [] \\ fs []
    \\ once_rewrite_tac [evaluate_append] \\ fs []
    \\ imp_res_tac evaluate_sing \\ fs [])
  >-
   (fs [case_eq_thms, pair_case_eq] \\ rw [] \\ fs [PULL_EXISTS]
    \\ qspec_then `e` strip_assume_tac compile_sing \\ fs []
    \\ imp_res_tac evaluate_sing \\ fs [])
  >-
   (fs [case_eq_thms, pair_case_eq] \\ rw [] \\ fs [PULL_EXISTS]
    \\ qspec_then `e` strip_assume_tac compile_sing \\ fs []
    \\ qmatch_asmsub_rename_tac `(compile_state s2, _)`
    \\ `?m. find_match env s2.refs v pes = Match m`
      by (CCONTR_TAC \\ fs []
          \\ imp_res_tac evaluate_match_find_match_none \\ fs [])
    \\ PairCases_on `m`
    \\ first_x_assum (CHANGED_TAC o (SUBST1_TAC o SYM))
    \\ qmatch_assum_rename_tac`_ = Match (env1,e1)`
    \\ `find_match env s2.refs v (const_cons_fst pes) = Match (env1, e1)`
      by metis_tac [const_cons_fst_find_match,
                    semanticPrimitivesTheory.match_result_distinct]
    \\ imp_res_tac find_match_imp_compile
    \\ imp_res_tac evaluate_match_find_match_some \\ fs [])
  >-
   (fs [case_eq_thms, pair_case_eq] \\ rw [] \\ fs [PULL_EXISTS]
    \\ rfs [compile_reverse, MAP_REVERSE, ETA_AX])
  >- (every_case_tac \\ fs [ALOOKUP_compile_env, PULL_EXISTS])
  >-
   (fs [case_eq_thms, pair_case_eq, bool_case_eq] \\ rw []
    \\ fs [compile_reverse, PULL_EXISTS, GSYM MAP_REVERSE]
    \\ fs [list_result_map_result]
    \\ qpat_x_assum `(_,_) = _` (assume_tac o GSYM) \\ fs []
    \\ qspec_then `e` strip_assume_tac compile_sing
    \\ fs [dec_clock_compile_state]
    \\ rfs [] \\ fs [])
  >-
   (fs [case_eq_thms, pair_case_eq] \\ rw [] \\ fs [PULL_EXISTS]
    \\ qspec_then `e1` strip_assume_tac compile_sing \\ fs []
    \\ imp_res_tac evaluate_sing \\ rw [] \\ fs []
    \\ fs [do_if_def]
    \\ rfs [case_eq_thms, bool_case_eq]
    \\ rw [] \\ fs [compile_v_def, Boolv_def]
    \\ qspec_then `e` strip_assume_tac compile_sing \\ fs [])
  >-
   (fs [case_eq_thms, pair_case_eq] \\ rw [] \\ fs [PULL_EXISTS]
    \\ qspec_then `e` strip_assume_tac compile_sing \\ fs []
    \\ imp_res_tac evaluate_sing \\ fs [] \\ rw []
    \\ qmatch_asmsub_rename_tac `(compile_state s2, _)`
    \\ `?m. find_match env s2.refs x0 pes = Match m`
      by (CCONTR_TAC \\ fs []
          \\ imp_res_tac evaluate_match_find_match_none \\ fs [])
    \\ PairCases_on `m`
    \\ first_x_assum (CHANGED_TAC o (SUBST1_TAC o SYM))
    \\ qmatch_assum_rename_tac`_ = Match (env1,e1)`
    \\ `find_match env s2.refs x0 (const_cons_fst pes) = Match (env1, e1)`
      by metis_tac [const_cons_fst_find_match,
                    semanticPrimitivesTheory.match_result_distinct]
    \\ imp_res_tac find_match_imp_compile
    \\ imp_res_tac evaluate_match_find_match_some \\ fs [])
  >-
   (fs [case_eq_thms, pair_case_eq] \\ rw [] \\ fs [PULL_EXISTS]
    \\ qspec_then `e1` strip_assume_tac compile_sing \\ fs []
    \\ imp_res_tac evaluate_sing \\ fs [] \\ rw []
    \\ qspec_then `e2` strip_assume_tac compile_sing \\ fs []
    \\ qpat_x_assum `evaluate _ _ [e2] = _` mp_tac
    \\ `env with v updated_by opt_bind n x0 =
        env with v := opt_bind n x0 env.v`
      by fs [environment_component_equality]
    \\ pop_assum SUBST1_TAC
    \\ fs [libTheory.opt_bind_def]
    \\ PURE_CASE_TAC \\ fs [])
  >-
   (fs [build_rec_env_merge, MAP_MAP_o, o_DEF, UNCURRY]
    \\ qspec_then `e` strip_assume_tac compile_sing \\ fs [])
  \\ fs [pmatch_compile_nil]
  \\ every_case_tac \\ fs [] \\ rfs []
  \\ qspec_then `e` strip_assume_tac compile_sing \\ fs []);

val _ = temp_bring_to_front_overload "compile_decs"
          { Name = "compile_decs", Thy = "flat_reorder_match" };

val compile_dec_evaluate = Q.store_thm("compile_dec_evaluate",
  `!d env s t c r.
     evaluate_dec env s d = (t, c, r) /\
     env.exh_pat /\
     ~env.check_ctor /\
     r <> SOME (Rabort Rtype_error)
     ==>
     ?r2.
       evaluate_dec (env with v := compile_env env.v)
                    (compile_state s)
                    (HD (compile_decs [d])) =
         (compile_state t, c, r2) /\
       r2 = OPTION_MAP (map_error_result compile_v) r`,
  Cases \\ rw [evaluate_dec_def]
  \\ fs [evaluate_dec_def, compile_decs_def]
  \\ fs [case_eq_thms, pair_case_eq] \\ rw [] \\ fs []
  \\ qspec_then `e` strip_assume_tac compile_sing \\ fs []
  \\ qispl_then [`env with v := []`,`s`] mp_tac (CONJUNCT1 compile_evaluate)
  \\ disch_then drule
  \\ rw [evaluate_dec_def] >>
  every_case_tac >>
  fs [] >>
  rw []);

val compile_decs_CONS = Q.store_thm("compile_decs_CONS",
  `compile_decs (d::ds) = compile_decs [d] ++ compile_decs ds`,
  rw [compile_decs_def] \\ every_case_tac \\ fs []);

val compile_decs_SING = Q.store_thm("compile_decs_SING",
  `!y. ?x. compile_decs [y] = [x]`,
  Cases \\ rw [compile_decs_def] \\ fs []);

val compile_decs_evaluate = Q.store_thm("compile_decs_evaluate",
  `!ds env s t c r.
     evaluate_decs env s ds = (t, c, r) /\
     env.exh_pat /\
     ~env.check_ctor /\
     r <> SOME (Rabort Rtype_error)
     ==>
     ?r2.
       evaluate_decs (env with v := compile_env env.v)
                     (compile_state s)
                     (compile_decs ds) =
         (compile_state t, c, r2) /\
         r2 = OPTION_MAP (map_error_result compile_v) r`,
  Induct >- (rw [evaluate_decs_def, compile_decs_def] \\ rw []) \\ rw[]
  \\ fs [evaluate_decs_def, case_eq_thms, pair_case_eq] \\ rw [] \\ fs []
  \\ once_rewrite_tac [compile_decs_CONS]
  \\ drule compile_dec_evaluate \\ rw [] \\ fs []
  \\ qspec_then `h` strip_assume_tac compile_decs_SING \\ fs []
  >- (last_x_assum drule \\ rw [evaluate_decs_def] \\ fs [])
  \\ simp [evaluate_decs_def]
  \\ every_case_tac \\ fs []
  \\ Cases_on `e` \\ Cases_on `a` \\ fs []);

val compile_decs_eval_sim = Q.store_thm("compile_decs_eval_sim",
  `eval_sim
     (ffi:'ffi ffi_state) T F ds1 T F
     (compile_decs ds1)
     (\p1 p2. p2 = compile_decs p1) F`,
  rw [eval_sim_def]
  \\ qexists_tac `0`
  \\ CONV_TAC (RESORT_EXISTS_CONV rev)
  \\ Q.LIST_EXISTS_TAC [`c1`,`compile_state s2`]
  \\ drule compile_decs_evaluate
  \\ impl_tac >- fs [initial_env_def] \\ rw []
  \\ fs[initial_env_def, initial_state_def, compile_state_def]);

val compile_decs_semantics = save_thm ("compile_decs_semantics",
  MATCH_MP (REWRITE_RULE [GSYM AND_IMP_INTRO] IMP_semantics_eq)
           compile_decs_eval_sim
  |> DISCH_ALL
  |> SIMP_RULE (srw_ss()) [AND_IMP_INTRO]);

(* syntactic results *)

(* TODO these are not available:

val _ = bring_to_front_overload"elist_globals"{Thy="flatProps",Name="elist_globals"};

val elist_globals_eq_empty = Q.store_thm("elist_globals_eq_empty",
  `elist_globals l = {||} ⇔ ∀e. MEM e l ⇒ set_globals e = {||}`,
  Induct_on`l` \\ rw[set_globals_def] \\ rw[EQ_IMP_THM] \\ rw[]);

val compile_elist_globals_eq_empty = Q.store_thm("compile_elist_globals_eq_empty",
  `∀es. elist_globals es = {||} ⇒ elist_globals (compile es) = {||}`,
  ho_match_mp_tac compile_ind
  \\ rw[compile_def]
  \\ TRY hd_compile_sing_tac \\ fs[]
  \\ fs[elist_globals_append]
  \\ TRY hd_compile_sing_tac \\ fs[]
  \\ fs[elist_globals_eq_empty]
  \\ fs[MEM_MAP,MAP_MAP_o,UNCURRY,o_DEF,PULL_EXISTS,FORALL_PROD]
  \\ rw[] \\ imp_res_tac const_cons_fst_MEM
  \\ res_tac
  \\ hd_compile_sing_tac \\ fs[]);

val compile_set_globals_eq_empty = Q.store_thm("compile_set_globals_eq_empty",
  `set_globals e = {||} ⇒ set_globals (HD (compile [e])) = {||}`,
  qspec_then`[e]`mp_tac compile_elist_globals_eq_empty
  \\ rw[] \\ fs[] \\ hd_compile_sing_tac \\ fs[]);

val compile_esgc_free = Q.store_thm("compile_esgc_free",
  `∀es. EVERY esgc_free es ⇒ EVERY esgc_free (compile es)`,
  ho_match_mp_tac compile_ind
  \\ rw[compile_def] \\ fs[]
  \\ hd_compile_sing_tac \\ fs[]
  \\ fs[EVERY_MAP,EVERY_MEM,FORALL_PROD,elist_globals_eq_empty]
  \\ fs[MEM_MAP,MAP_MAP_o,PULL_EXISTS,FORALL_PROD]
  \\ rw[]
  \\ TRY(
    match_mp_tac compile_set_globals_eq_empty
    \\ res_tac )
  \\ METIS_TAC[compile_sing,HD,MEM,const_cons_fst_MEM,compile_set_globals_eq_empty]);

val const_cons_sep_sub_bag = Q.store_thm("const_cons_sep_sub_bag",
  `∀pes a const_cons c a'.
    const_cons_sep pes a const_cons = (c,a') ⇒
    elist_globals (MAP SND (c ++ REVERSE a')) ≤
    elist_globals (MAP SND (const_cons ++ REVERSE a ++ pes))`,
  Induct_on`pes` \\ rw[const_cons_sep_def]
  \\ fs[elist_globals_append,REVERSE_APPEND]
  \\ fs[SUB_BAG_UNION]
  \\ first_x_assum drule \\ rw[elist_globals_append]
  \\ metis_tac[SUB_BAG_UNION,ASSOC_BAG_UNION,COMM_BAG_UNION]);

val const_cons_fst_sub_bag = Q.store_thm("const_cons_fst_sub_bag",
  `elist_globals (MAP SND (const_cons_fst pes)) ≤
   elist_globals (MAP SND pes)`,
  rw[const_cons_fst_def]
  \\ pairarg_tac \\ fs[]
  \\ imp_res_tac const_cons_sep_sub_bag \\ fs[])

val const_cons_fst_distinct_globals = Q.store_thm("const_cons_fst_distinct_globals",
  `BAG_ALL_DISTINCT (elist_globals (MAP SND pes)) ⇒
   BAG_ALL_DISTINCT (elist_globals (MAP SND (const_cons_fst pes)))`,
  METIS_TAC[const_cons_fst_sub_bag,BAG_ALL_DISTINCT_SUB]);

val compile_sub_bag = Q.store_thm("compile_sub_bag",
  `∀es. (elist_globals (compile es)) ≤ (elist_globals es)`,
  ho_match_mp_tac compile_ind
  \\ rw[compile_def]
  \\ TRY hd_compile_sing_tac \\ fs[SUB_BAG_UNION,elist_globals_append]
  \\ TRY hd_compile_sing_tac \\ fs[SUB_BAG_UNION]
  \\ fs[MAP_MAP_o,UNCURRY,o_DEF] \\ fs[LAMBDA_PROD]
  \\ FIRST (map (fn th => match_mp_tac (MP_CANON th) \\ conj_tac >- simp[]) (CONJUNCTS SUB_BAG_UNION))
  \\ TRY (
    ntac 3 (pop_assum kall_tac)
    \\ Induct_on`funs` \\ fs[FORALL_PROD] \\ rw[]
    \\ hd_compile_sing_tac \\ fs[]
    \\ first_x_assum(fn th => mp_tac th \\ impl_tac >- METIS_TAC[])
    \\ fsrw_tac[DNF_ss][SUB_BAG_UNION] )
  THEN_LT USE_SG_THEN ACCEPT_TAC 1 2
  \\ match_mp_tac SUB_BAG_TRANS
  \\ qexists_tac`elist_globals (MAP SND (const_cons_fst pes))`
  \\ (reverse conj_tac >- METIS_TAC[const_cons_fst_sub_bag])
  \\ ntac 3 (pop_assum kall_tac)
  \\ pop_assum mp_tac
  \\ Q.SPEC_TAC(`const_cons_fst pes`,`ls`)
  \\ Induct \\ rw[]
  \\ pairarg_tac \\ fs[]
  \\ hd_compile_sing_tac \\ fs[]
  \\ first_x_assum (fn th => mp_tac th \\ impl_tac >- METIS_TAC[])
  \\ fsrw_tac[DNF_ss][UNCURRY,SUB_BAG_UNION]);

val compile_distinct_globals = Q.store_thm("compile_distinct_globals",
  `BAG_ALL_DISTINCT (elist_globals es) ⇒ BAG_ALL_DISTINCT (elist_globals (compile es))`,
  METIS_TAC[compile_sub_bag,BAG_ALL_DISTINCT_SUB]);
*)

val () = export_theory();
