%macro declare_hash(hash_name, dsn_exp, keys, data, multidata=NO) / minoperator store source;

%* This macro is designed to replace the quick and easy declaration of hash tables.
   If more complicated options are used (e.g. no dataset, duplicate='r', etc., then
   this macro should NOT be used (would defeat the point of simplicity if it does
   complex/uncommon hash declarations)) ;

%* HASH_NAME: name of hash table;
%* DSN_EXP: full dataset name with data set options requested (can be blank if not based on data);
%* KEYS: comma separated (macro quoted) list of unquoted variable names;
%* DATA: comma separated (macro quoted) list of unquoted variable names or blank (in the case of all variables being requested, ALL:'YES');
%* MULTIDATA: NO or YES flag, allows functionality of FIND / FIND_NEXT search operations;

%* Usage note:
      If a KEEP=/DROP= is not provided in the DSN_EXP, then it will be generated based on
      only variables referenced in the KEYS and DATA parameters

%* Macro dependencies: MODIFY_MLIST, HASH_CR8_INVERSE_NAME_FMT ;

   %local rc keep_list i;
   
   %let keys = %upcase(%superq(keys));
   %let data = %upcase(%superq(data));

   %if %superq(multidata) ne NO %then %let multidata = YES;

   %* Case 1: DATA parameter blank, use all variables from DSN_EXP (after factoring KEEP=/DROP=) ;
   %if %superq(data) =  %then %let data = ALL:'YES';

   %* Case 2: DATA parameter nonblank, but a KEEP=/DROP= is already provided -> just prepare DATA ;
   %else %if %sysfunc(prxmatch( %str(~(keep|drop)\s*=~i) , %superq(dsn_exp) )) %then %do;
      %let data = %modify_mlist(%superq(data),add_prefix=%bquote('), add_suffix=%bquote('));
   %end;
 
   %* Case 3: DATA parameter nonblank and no KEEP=/DROP= provided ;
   %else %do;
      
      %* Create inverse format between post_name (fields listed in KEYS and DATA) -> pre_name (before RENAME=) ;
      %if %sysfunc(prxmatch( %str(~rename\s*=\s*\%(~i) , %superq(dsn_exp) )) %then %do;
         %local dsn_exp_rename dsn_exp_norename rc_h_inv_name;
         %let dsn_exp_rename = &dsn_exp;
         %let dsn_exp_norename = %sysfunc(prxchange( %bquote(s~rename\s*=\s*\(.*?\)~ ~i),1,%superq(dsn_exp) ));
         
         %let rc = %sysfunc(dosubl(%nrbquote( %hash_cr8_inverse_name_fmt(%superq(dsn_exp_rename),%superq(dsn_exp_norename)) )));
      %end;

      %* Identify any variables on a WHERE= statement;
      %* TO BE COMPLETED ;

      %* The format $H_INV_NAME. has been created, with input being renamed variable names ;

      %* Create variables based off of DATA and KEYS ;
      %let keep_list = keep= ;
      
         %* KEYS ;
      %do i = 1 %to %sysfunc(countw(%superq(keys),%str(,)));
         %let var = %scan(%superq(keys), &i, %str( ,));
         %if %symexist(rc_h_inv_name) %then %let keep_list = &keep_list %sysfunc(putc(&var,$h_inv_name.)) ;
         %else %let keep_list = &keep_list &var;
      %end;
      
         %* DATA ;
      %do i = 1 %to %sysfunc(countw(%superq(data),%str(,)));
         %let var = %scan(%superq(data), &i, %str( ,));
         
         %if not %index(%superq(keep_list), &var) %then %do;
            %if %symexist(rc_h_inv_name) %then %let keep_list = &keep_list %sysfunc(putc(&var,$h_inv_name.)) ;
            %else %let keep_list = &keep_list &var;
         %end;
      %end;
      

      %* Attach KEEP= option to the end of DSN_EXP by striping off the last parentheses ;
      %if %index(%superq(dsn_exp), %str(%))) %then %do;   
         %let dsn_exp = %substr(%superq(dsn_exp)
                              , 1
                              , %qsysfunc(findc( %superq(dsn_exp),%str(%(%)),%str(b) )) - 1
                                ) &keep_list ) ;
      %end;
      %else %do;
         %let dsn_exp = &dsn_exp (&keep_list);
      %end;

      %let data = %modify_mlist(%superq(data),add_prefix=%bquote('), add_suffix=%bquote('));
   %end;

   %let keys = %modify_mlist(%superq(keys),add_prefix=%bquote('), add_suffix=%bquote('));

   if _n_ = 0 then set &dsn_exp;
   declare hash &hash_name(dataset:"&dsn_exp", multidata:"&multidata");
   &hash_name..definekey(&keys);
   &hash_name..definedata(&data);
   &hash_name..definedone();

%mend declare_hash;
