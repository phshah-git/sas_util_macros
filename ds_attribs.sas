%macro ds_attribs() / parmbuff store source;
/*-----------------------------------------------------------------------------*/
/*-----------------------------------------------------------------------------*/
/* MACRO DESCRIPTION:                                                          */
/*    Creates ATTRIB statements for all variables so that shared variables     */
/*    have a length of the maximum between the two to prevent truncation.      */
/*    This is exactly like DS_SET but without the SET statement (which         */
/*    prevents implicit retaining of variables)                                */
/*                                                                             */
/* Notable similarities with SET statement:                                    */
/*  - Variables will be assigned in variable order from first DSN variables,   */
/*    to new second DSN variables, to new third DSN variables, etc.            */
/*                                                                             */
/*  - Variable format and labels are taken from the first dataset with the     */
/*    attribute                                                                */
/*                                                                             */
/*  - Supports supplying KEEP=, DROP=, RENAME= dataset options                 */
/*                                                                             */
/*  - Supports listing variables using a name literal, e.g. 'Variable 1,A'n    */
/*                                                                             */
/*-----------------------------------------------------------------------------*/
/*-----------------------------------------------------------------------------*/
/* USAGE DOCUMENTATION:                                                        */
/*  - Use %DS_ATTRIBS in the DATA step before you delcare relevant variables   */
/*                                                                             */
/*  - Supply a comma separated list of each of the datasets that you would     */
/*    put on a SET statement to define variables                               */
/*                                                                             */
/*  - If applicable, supply DROP=, KEEP=, RENAME= options as you would in      */
/*    any other step (in parentheses after the data set) to alter how the      */
/*    attrib statements are created                                            */
/*                                                                             */
/*  - Example given below (extra carriage returns to fit in the comment block) */
/*                                                                             */
/*    data CONCAT_TABLES;                                                      */
/*       %DS_ATTRIBS(empty_metadata_table, rawdata_table);                     */
/*       set rawdata_table;                                                    */
/*    run;                                                                     */
/*                                                                             */
/*  - For assistance in troubleshooting/testing this macro program, include    */
/*    an exclamation point (!) BEFORE THE FIRST TABLE to prevent deleting      */
/*    intermediate tables.  Example given below.                               */
/*                                                                             */
/*       %DS_ATTRIBS( ! table1, table2)                                        */
/*                                                                             */
/*    WARNING: Exclamation points after the first character in the input are   */
/*             ignored and assumed to be a part of the table/data set options  */
/*                                                                             */
/*  - If a character variable is first defined with the $w. format, then the   */
/*    format is edited so that the width matches the longest length            */
/*                                                                             */
/*-----------------------------------------------------------------------------*/
/*-----------------------------------------------------------------------------*/
/* POSSIBLE 'GOTCHA'S TO LOOK OUT FOR:                                         */
/*  - If you assign the length of a PDV variable that comes from any tables    */
/*    BEFORE the %DS_ATTRIBS, then (similar to when using a MERGE statement)   */
/*    that first assignment initializes the variable, not %DS_ATTRIBS          */
/*                                                                             */
/*  - Avoid using commas in the data set options (e.g. WHERE=) to avoid        */
/*    ambiguity with the data set delimiter (,)                                */
/*-----------------------------------------------------------------------------*/

   /*------------------------------------------------------*/
   /* Get DSN expressions (tables and dataset options)     */
   /*------------------------------------------------------*/

   %let syspbuff = %qsubstr(%superq(syspbuff),2,%length(%superq(syspbuff))-2);

   %* Check for test parameter '!';
   %local test_macro;
   %if %qsysfunc(first(%qsysfunc(left(%superq(syspbuff))))) = %str(!) %then %do;
      %let test_macro = 1 ;
      %let syspbuff = %qsubstr(%qsysfunc(left(%superq(syspbuff))), 2);
   %end;

   %put NOTE: Input provided: ;
   %put NOTE: %superq(syspbuff);


   %local i num_tables;
   %let num_tables = %sysfunc(countw(%superq(syspbuff),%str(,),q));

   %local exp_norenamewhere exp_in;
   %do i = 1 %to &num_tables;
      %local dsn_exp&i dsn_contents_exp&i;
      %let dsn_exp&i = %qupcase(%qscan(%superq(syspbuff),&i,%str(,),q));

      %let exp_norenamewhere = %qsysfunc(prxchange(s!(rename|where)\s*=\s*\(.*?\)! !i,1,%superq(dsn_exp&i)));
      %if %qsysfunc(prxmatch(!in\s*=\s*\w+!i,%superq(exp_norenamewhere))) %then %do;
         %let exp_in = %qsysfunc(prxchange(s!.*?in\s*=\s*(\w+).*!IN=$1!i,1,%superq(exp_norenamewhere))) ;
         %let dsn_contents_exp&i = %qsysfunc(prxchange(s~%superq(exp_in)~ ~i,1,%superq(dsn_exp&i))) ;
      %end;
      %else %let dsn_contents_exp&i = &&dsn_exp&i;
   %end;

   /*------------------------------------------------------*/
   /* Define the GET_VAR_INFO macro to be called in DOSUBL */
   /*------------------------------------------------------*/

   %macro get_var_info;

      %* Get variable info using PROC CONTENTS ;
      %do i = 1 %to &num_tables;
         proc contents data=%unquote(&&dsn_contents_exp&i) noprint out=_getvarinfo&i;
         run;
         proc sort data=_getvarinfo&i;
            by varnum;
         run;
      %end;

      /* NOTE:
         type=2 => char
         type=1 => num */

      %* Load variable info into hash table ;
      %* Hash table is used to support updating a previously loaded record ;
      data _null_;

         declare hash out();
         out.definekey('hname');
         out.definedata('hname','htype','hlength','hlabel','hfmt','_hvarorder');
         out.definedone();

         length hname $ 32
                htype hlength 8
                hlabel $ 256
                hfmt $ 40;

         varorder + 1;

         %do i = 1 %to &num_tables;
            do until(last&i);
               set _getvarinfo&i end=last&i;

               rc = out.find(key:lowcase(name));
               if (rc = 0) then do;

                  if type ne htype then do;
                     putlog 'ERROR: [dev] Variable type differs for the given variable:' name;
                     putlog 'ERROR: [dev] Macro will now ABORT CANCEL.';
                     abort cancel;
                  end;

                  hlength = max(hlength,length);
                  hlabel = coalescec(hlabel,label);

                  if formatl ne 0 and hfmt = ' '
                     then hfmt = ifc(type=1, cats(format,formatL,'.',formatD),cats(format,formatL,'.'));

                  if type = 2 and prxmatch('/^\$\d+\.$/',strip(hfmt))
                     then hfmt = cats('$',hlength,'.');

                  out.replace();
               end;
               else do;

                  hname = lowcase(name);
                  htype = type;
                  hlength = length;
                  hlabel = label;
                  _hvarorder = varorder;

                  if formatl ne 0 and hfmt = ' ' then hfmt = ifc(type=1, cats(format,formatL,'.',formatD),cats(format,formatL,'.'));
                  out.add();
               end;

               varorder+1;
               call missing(of h:);
            end;
         %end;

         out.output(dataset:'_hvarinfo_all');

         stop;
      run;

      %* Sort by the _HVARORDER variable to imitate SET/MERGE statement assignment order ;
      proc sort data=_hvarinfo_all out=_hvarinfo_all(drop=_hvarorder);
         by _hvarorder;
      run;

      %* Create macro variables to hold ATTRIB statements
         Global scope since they will be used outside this macro ;
      data _null_;
         set _hvarinfo_all end=last;

         attrib_statement = catx(' '
                                , 'attrib'
                                , cats('"',prxchange('s/(")/$1$1/',-1,hname),'"n')
                                , cats('length=',ifc(htype=2, '$',' '), hlength)
                                , ifc(hfmt ne ' ', cats('format=',hfmt),' ')
                                , ifc(hlabel ne ' ', cats('label="',prxchange('s/(")/$1$1/',-1,hlabel),'"'), ' ')
                                , ';'
                                 );

         call symputx(cats('_attrib',_n_) , attrib_statement, 'G');

         if last then call symputx('num_attribs',_n_,'G');
      run;

      %if &test_macro ne 1 %then %do;
         proc delete data=_hvarinfo_all %do i = 1 %to &num_tables; _getvarinfo&i %end; ;
         run;
      %end;


   %mend get_var_info;

%* Call macro using DOSUBL so none of the above steps to DATA step compiler 
   holding the currently queued code ;
%local rc;
%let rc = %sysfunc(dosubl(%nrbquote(%get_var_info)));

%do i = 1 %to &num_attribs;
   %unquote(&&_attrib&i)
   %symdel _attrib&i;
%end;
%symdel num_attribs;

%mend ds_attribs;
