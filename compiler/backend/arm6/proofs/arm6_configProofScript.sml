open preamble backendProofTheory
     arm6_configTheory arm6_targetProofTheory
open blastLib;

val _ = new_theory"arm6_configProof";

val is_arm6_machine_config_def = Define`
  is_arm6_machine_config mc ⇔
  mc.target = arm6_target ∧
  mc.len_reg = 1  ∧
  mc.ptr_reg = 0 ∧
  mc.len2_reg = 3  ∧
  mc.ptr2_reg = 2 ∧                                 
  mc.callee_saved_regs = [8;10;11]`;

val names_tac =
  simp[tlookup_bij_iff] \\ EVAL_TAC
  \\ REWRITE_TAC[SUBSET_DEF] \\ EVAL_TAC
  \\ rpt strip_tac \\ rveq \\ EVAL_TAC

val arm6_backend_config_ok = Q.store_thm("arm6_backend_config_ok",`
  backend_config_ok arm6_backend_config`,
  simp[backend_config_ok_def]>>rw[]>>TRY(EVAL_TAC>>NO_TAC)
  >> TRY(fs[arm6_backend_config_def]>>NO_TAC)
  >- (EVAL_TAC>> blastLib.FULL_BBLAST_TAC)
  >> TRY(EVAL_TAC >> fs[armTheory.EncodeARMImmediate_def,Once armTheory.EncodeARMImmediate_aux_def]>>NO_TAC)
  >- names_tac
  >- (
    fs [stack_removeTheory.store_offset_def,
        stack_removeTheory.store_pos_def]
    \\ every_case_tac \\ fs [] THEN1 EVAL_TAC
    \\ fs [stack_removeTheory.store_list_def]
    \\ fs [INDEX_FIND_CONS_EQ_SOME,EVAL ``INDEX_FIND n f []``]
    \\ rveq \\ fs [] \\ EVAL_TAC)
  \\ fs[stack_removeTheory.max_stack_alloc_def]
  \\ EVAL_TAC>>fs[]
  \\ simp [armTheory.EncodeARMImmediate_def,
           Once (GSYM wordsTheory.word_mul_n2w)]
  \\ qabbrev_tac `w = n2w n : word32`
  \\ `w <=+ 255w` by simp [Abbr `w`, wordsTheory.word_ls_n2w]
  \\ NTAC 16
       (simp [Once armTheory.EncodeARMImmediate_aux_def]
        \\ rw [boolTheory.COND_RAND])
  \\ blastLib.FULL_BBLAST_TAC);

val arm6_machine_config_ok = Q.store_thm("arm6_machine_config_ok",
  `is_arm6_machine_config mc ⇒ mc_conf_ok mc`,
  rw[lab_to_targetProofTheory.mc_conf_ok_def,is_arm6_machine_config_def]
  >- EVAL_TAC
  >- simp[arm6_targetProofTheory.arm6_backend_correct]
  >- EVAL_TAC
  >- EVAL_TAC
  >- EVAL_TAC
  >- EVAL_TAC
  >- EVAL_TAC
  >- metis_tac[asmPropsTheory.backend_correct_def,asmPropsTheory.target_ok_def,arm6_backend_correct]);

val arm6_init_ok = Q.store_thm("arm6_init_ok",
  `is_arm6_machine_config mc ⇒
    mc_init_ok arm6_backend_config mc`,
  rw[mc_init_ok_def] \\
  fs[is_arm6_machine_config_def] \\
  EVAL_TAC);

val is_arm6_machine_config_mc = arm6_init_ok |> concl |> dest_imp |> #1

val arm6_compile_correct =
  compile_correct
  |> Q.GENL[`c`,`mc`]
  |> Q.ISPECL[`arm6_backend_config`, `^(rand is_arm6_machine_config_mc)`]
  |> ADD_ASSUM is_arm6_machine_config_mc
  |> SIMP_RULE (srw_ss()) [arm6_backend_config_ok,UNDISCH arm6_machine_config_ok,UNDISCH arm6_init_ok]
  |> CONV_RULE (ONCE_DEPTH_CONV(EVAL o (assert(same_const``heap_regs``o fst o strip_comb))))
  |> DISCH_ALL
  |> curry save_thm"arm6_compile_correct";

val _ = export_theory();
