/*---------------------------------------------------------------------------*/
/* Macro: scrape_filenames(DS, FILELOC)                                      */
/*                                                                           */
/*	- DS		---	A data set name into which to put the results.           */
/*  - FILELOC	---	The path of the directory to check. This argument should */
/*					be macro quoted if necessary.                            */
/*	- DETAILS	--- Optional keyword parameter to include all the directory  */
/*					attributes for the file in the output. There will be     */
/*                  multiple entries for each file, with option name         */
/*					(optname) and option value (optval) pairs. The option    */
/*					name is converted to upper case.                         */
/*	- LASTMOD	--- Optional keyword parameter to include last modified date */
/*					(mod_date) and date=time (mod_dtime) to the listing.     */
/*                  This takes precedence over DETAILS.                      */
/*	- CREATED	--- Optional keyword parameter to include created date       */
/*					(create_date) and date=time (create_dtime) to the        */
/*                  listing.                                                 */
/*                  This takes precedence over DETAILS.                      */
/*                                                                           */
/*					For example:                                             */
/*						%scrape_filenames(RESULT, "%str(H:\What or not)"     */
/*                  or:                                                      */
/*						%scrape_filenames(RESULT, "%superq(MACRO_VAR)"       */
/*                                                                           */
/* Returns: Data set DS is created, with the name of the files in memname.   */
/*                                                                           */
/* This macro is a quick and efficient way to get a list of files in a       */
/* directory. Even for SAS data sets, this is significantly faster than      */
/* using DICTIONARY.TABLES.                                                  */
/*---------------------------------------------------------------------------*/
%macro scrape_filenames(DS, FILELOC,	DETAILS = ,
										LASTMOD = ,
										CREATED = )
			/ store source
		;
	proc optsave out = SF___OPTS_SCRAPE_FILENAMES; run;
	options nonotes nosource nosource2 nomprint nomlogic nosymbolgen varlenchk = nowarn;

	%local SOURCE_DIR;
	%let SOURCE_DIR = &FILELOC;

	%if &LASTMOD ^= or &CREATED ^= %then %let DETAILS = Y;

	/* Process the location:                                                 */
	/*  -- strip leading and trailing quotes                                 */
	/*  -- if it does not have a trailing slash, add one.                    */
	data _NULL_;
		length source_dir $300;
		source_dir = dequote(strip(symget('SOURCE_DIR')));
		if char(source_dir, lengthn(source_dir)) ^= '\' then do;
			source_dir = cats(source_dir, '\');
		end;
		call symputx('SOURCE_DIR', source_dir);
	run;

	filename SF__ADIR "&SOURCE_DIR";
	data &DS;
		%if &DETAILS ^= %then %do;
			length memname $120 optname $30 optval $300;
		%end;

		handle = dopen('SF__ADIR');
		if handle > 0 then do;
			count = dnum(handle);
			do i = 1 to count;
				memname = dread(handle, i);
				output;

				%if &DETAILS ^= %then %do;
					rc = filename('SF__AFIL', cats("&SOURCE_DIR", memname));
					f_handle = fopen('SF__AFIL');
					if f_handle > 0 then do;
						numopts = foptnum(f_handle);
						do j = 1 to numopts;
							optname = upcase(foptname(f_handle, j));
							optval = finfo(f_handle, optname);
							output;
						end;
					end;
					rc = fclose(f_handle);
					rc = filename('SF__AFIL', '');
				%end;

			end;
		end;
		rc = dclose(handle);

		keep	memname
				%if &DETAILS ^= %then %do;
					optname optval
				%end;
				;

	run;

	%if &LASTMOD ^= or &CREATED ^= %then %do;
		proc sort data = &DS; by memname; run;
		data &DS;
			set &DS;
			format	mod_dtime		e8601dt.
					mod_date		e8601da.
					create_dtime	e8601dt.
					create_date		e8601da.
					create			e8601dt.
					lastmod			e8601dt.;
			retain	create
					lastmod;
			by memname;

			if first.memname then do;
				create = .;
				lastmod = .;
			end;

			select (optname);
				when ('CREATE TIME') do;
					if create = .
						then create = input(optval, ?? anydtdtm.);
						else create = min(create,
											input(optval, ?? anydtdtm.));
				end;
				when ('LAST MODIFIED') do;
					if lastmod = .
						then lastmod = input(optval, ?? anydtdtm.);
						else lastmod = max(lastmod,
											input(optval, ?? anydtdtm.));
				end;
				otherwise ;
			end;

			if last.memname then do;
				mod_dtime = max(create, lastmod);
				mod_date = datepart(mod_dtime);
				create_dtime = min(create, lastmod);
				create_date = datepart(create_dtime);
				output;
			end;

			keep	memname
					%if &LASTMOD ^= %then %do;
						mod_dtime
						mod_date
					%end;
					%if &CREATED ^= %then %do;
						create_dtime
						create_date
					%end;
					; 
		run;
	%end;

	filename SF__ADIR clear;

	proc optload data = SF___OPTS_SCRAPE_FILENAMES; run;
	proc delete data = SF___OPTS_SCRAPE_FILENAMES; run;
%mend scrape_filenames;

/*---------------------------------------------------------------------------*/
/* Macro: scrape_datasets(DS, LIB)                                           */
/*                                                                           */
/*	- DS	---	A data set name into which to put the results.               */
/*  - LIB	---	The libname in which to search                               */
/*                                                                           */
/*			--- It also accepts all %scrape_datasets arguments. Note that    */
/*              the last modified date and datetime returned by LASTMOD are */
/*				the system values, not the data set attributes set by SAS.   */
/*                                                                           */
/* Returns: Data set DS is created, with any data sets in that location in   */
/*          upper case. The extension is stripped so the values can be used  */
/*          directly in code generation.                                     */
/*                                                                           */
/* This macro is a quick and efficient way to get a list of data sets in a   */
/* directory. This is significantly faster than  using DICTIONARY.TABLES.    */
/*---------------------------------------------------------------------------*/
%macro scrape_datasets(DS, LIB, DETAILS = , LASTMOD = , CREATED = )
			/ store source
		;
	proc optsave out = SF___OPTS_SCRAPE_DATASETS; run;
	options nonotes nosource nosource2 nomprint nomlogic nosymbolgen varlenchk = nowarn;

	%local LIB_LOCATION;
	%let LIB_LOCATION = "%sysfunc(pathname(&LIB))";
	%scrape_filenames(SDS______LIST, &LIB_LOCATION, DETAILS = &DETAILS, LASTMOD = &LASTMOD);
	data &DS;
		length memname $32;
		set SDS______LIST (rename = (memname = file_name));
		if index(file_name, '.sas7bdat') and not index(file_name, '.sas7bdat.lck');
		memname = upcase(left(tranwrd(file_name, '.sas7bdat', '')));
		drop file_name;
	run;
	proc delete data = SDS______LIST; run;

	proc optload data = SF___OPTS_SCRAPE_DATASETS; run;
	proc delete data = SF___OPTS_SCRAPE_DATASETS; run;
%mend scrape_datasets;
