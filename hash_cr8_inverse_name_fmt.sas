%macro hash_cr8_inverse_name_fmt(dsn_exp_start, dsn_exp_label) / store source;
   %* This macro is strictly used for the DECLARE_HASH macro ;

   %* Intended usage: Given a DSN expression (with dataset options),
      provide it with a RENAME= option as DSN_EXP_START and provide
      it again as DSN_EXP_LABEL ;

   %* Creates the format $H_INV_NAME. to use to translate variables
      from START table to LABEL table (based on variable order);

   %local i prefix1 prefix2 rc;
   
   options nonotes nosource nosource2;

   %let prefix1 = start;
   %let prefix2 = label;

   %do i = 1 %to 2;
      proc contents data=&&&&dsn_exp_&&prefix&i out=_&&prefix&i.._name(keep=varnum name rename=(name=&&prefix&i.._name)) noprint;
      run;

      proc sort data=_&&prefix&i.._name;
         by varnum;
      run;
   %end;

   data _inv_names;
      merge _start_name _label_name;
      by varnum;

      drop varnum start_name label_name;

      retain fmtname '$h_inv_name'
             default 32
             type 'C';

      start = lowcase(start_name);
      label = lowcase(label_name);
   run;

   proc format cntlin=_inv_names ;
   run;

   proc delete data=_inv_names _start_name _label_name;
   run;
   
   options notes source source2;

%mend hash_cr8_inverse_name_fmt;
