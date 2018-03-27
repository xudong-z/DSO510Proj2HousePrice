/* 1. Load data */
  
LIBNAME MyLib "~/MyLibrary";  /** Define library location **/
PROC IMPORT  /** Import file into library **/
	DATAFILE="~/MyData/HouseTaxJoinedFile.xlsx"
	OUT=MyLib.DSO510Proj2
	DBMS=XLSX
	REPLACE;  /** Overwrite the dataset if it already exists **/
RUN;


/* 2. Exploratory Data Analysis */


/*BarChart: The BldgType distribution on different House SubClass*/
ods graphics / reset width=6.4in height=4.8in imagemap;

proc sgplot data=MYLIB.DSO510PROJ2;
	vbar MSSubClass / group=BldgType groupdisplay=cluster;
	yaxis grid;
run;

ods graphics / reset;

/*LineChart: The distribution of different housestyles on 12 month*/
ods graphics / reset width=6.4in height=4.8in imagemap;

proc sgplot data=MYLIB.DSO510PROJ2;
	vline MoSold / group=HouseStyle;
	yaxis grid;
run;

ods graphics / reset;

/*Combined*/
options validvarname=any;
ods noproctitle;
ods graphics / imagemap=on;

/* Histogram (one-way or two-way) */
%macro DEHisto(data=, avar=, classVar=);
	%local i numAVars numCVars cVar cVar1 cVar2;
	%let numAVars=%Sysfunc(countw(%str(&avar), %str( ), %str(q)));
	%let numCVars=%Sysfunc(countw(%str(&classVar), %str( ), %str(q)));

	%if(&numAVars>0 & &numCVars>0) %then
		%do;

			%if(&numCVars=1) %then
				%do;
					%let cVar=%scan(%str(&classVar), 1, %str( ), %str(q));

					proc sql noprint;
						select count(distinct &cVar) into :nrows from &data;
					quit;

					/* One-way histogram */
					proc univariate data=&data noprint;
						var &avar;
						class &cVar;
						histogram &avar / nrows=&nrows
             normal(noprint);
					run;

				%end;
			%else
				%do;

					/* One-way histogram of each class variable */
                
					%do i=1 %to %eval(&numCVars);
						%let cVar=%scan(%str(&classVar), &i, %str( ), %str(q));

						proc sql noprint;
							select count(distinct &cVar) into :nrows from &data;
						quit;

						proc univariate data=&data noprint;
							var &avar;
							class &cVar;
							histogram &avar / nrows=&nrows
                 normal(noprint);
						run;

					%end;

					/* Two-way histogram */
                %let cVar1=%scan(%str(&classVar), 1, %str( ), 
						%str(q));
					%let cVar2=%scan(%str(&classVar), 2, %str( ), %str(q));

					proc sql noprint;
						select count(distinct &cVar1) into :nrows from &data;
					quit;

					proc sql noprint;
						select count(distinct &cVar2) into :ncols from &data;
					quit;

					proc univariate data=&data noprint;
						var &avar;
						class &cVar1 &cVar2;
						histogram &avar / nrows=&nrows ncols=&ncols
             normal(noprint);
					run;

				%end;
		%end;
%mend DEHisto;

%DEHisto(data=MYLIB.DSO510PROJ2, avar=TotSF, classVar=Alley Street);


/* 3. ANOVA*/

Title;
ods noproctitle;
ods graphics / imagemap=on;

proc glm data=MYLIB.DSO510PROJ2;
	class MSSubClass;
	model SalePrice=MSSubClass;
	means MSSubClass / hovtest=levene welch plots=none;
	lsmeans MSSubClass / adjust=tukey pdiff alpha=.05;
	run;
quit;




/* 4. Linear Regression*/

ods noproctitle;
ods graphics / imagemap=on;

proc glmselect data=MYLIB.DSO510PROJ2 outdesign(addinputvars)=Work.reg_design 
		plots=(criterionpanel);
	model SalePrice=OverallQual YearBuilt GarageCars TotSF neighborhoodscore / 
		showpvalues selection=forward 
    
   (select=bic stop=aicc choose=aicc) details=steps(anova fitstats) 
		stats=all;
run;

proc reg data=Work.reg_design alpha=0.05 plots(only)=(diagnostics residuals 
		observedbypredicted);
	ods select DiagnosticsPanel ResidualPlot ObservedByPredicted;
	model SalePrice=&_GLSMOD /;
	output out=WORK.Reg_stats p=p_ lcl=lcl_ ucl=ucl_ lclm=lclm_ uclm=uclm_ r=r_;
	run;
quit;

proc delete data=Work.reg_design;
run;
