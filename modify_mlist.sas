%macro modify_mlist(string, dlm_charlist=%str( ,), add_prefix=, add_suffix=, replace_dlm=) / store source;
%*----------------------------------------------------------------------------*;
%* STRING - list of delimited words                                           *;
%* DLM_CHARLIST - delimiter for words in STRING                               *;
%*                                                                            *;
%* ADD_PREFIX - characters to add before each word in STRING                  *;
%* ADD_SUFFIX - characters to add after each word in STRING                   *;
%*  * NOTE: Above can use substitution regex characters, like $1 to add the   *;
%*          the matched string as a prefix or suffix                          *;
%*                                                                            *;
%* REPLACE_DLM - characters to replace all consecutive delimiters             *;
%*                                                                            *;
%* Common applications:                                                       *;
%*                                                                            *;
%*  - Append prefix for a RENAME= option:                                     *;
%*       %modify_mlist(var1 var2 var3, add_prefix=%str($1=new_))              *;
%*         -> returns: var1=new_var1 var2=new_var2 var3=new_var3              *;
%*                                                                            *;
%*  - Get a comma separated list of quoted values for an IN operator          *;
%*       %modify_mlist(PPN1 PPN2, add_prefix=%bquote(")                       *;
%*                              , add_suffix=%bquote(")                       *;
%*                              , replace_dlm=%str(,)                         *;
%*                     )                                                      *;
%*         -> returns: "PPN1","PPN2"                                          *;
%*----------------------------------------------------------------------------*;

%if %superq(string) = %then %do;
   %put ERROR: [dev] List to modify (first parameter) was not provided.;
   %put ERROR: [dev] Macro will ABORT CANCEL.;
   %abort cancel;
%end;
%else %if %superq(add_prefix) =  and %superq(add_suffix) = and %superq(replace_dlm) =  %then %do;
   %put WARNING: [dev] Neither ADD_PREFIX=, ADD_SUFFIX=, nor replace_dlm= parameters were given.;
   %put WARNING: [dev] Supply at least one parameter to utilize this macro.;
   %put WARNING: [dev] Original list will be returned.;
   %superq(string);
%end;
%else %do;
   %* BE SURE TO ESCAPE the charaters in the ADD_PREFIX or ADD_SUFFIX parameters with \
      TO MASK PRX METACHARACTERS! E.g. \$ for $ or \\ for \;

   %if %superq(replace_dlm) ne %then %do;
      %put NOTE: [dev] delimiting characters (%superq(dlm_charlist)) replaced with new delimiter (%superq(replace_dlm));
      %let string = %qsysfunc(prxchange(s~[%superq(dlm_charlist)]+~%superq(replace_dlm)~,-1,%superq(string)));
      %let dlm_charlist = %superq(replace_dlm);
   %end;

   %unquote(%qsysfunc(prxchange(s!([^%superq(dlm_charlist)]+)!%superq(add_prefix)$1%superq(add_suffix)!,-1,%superq(string))))

%end;

%mend modify_mlist;