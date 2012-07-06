/*
 * Copyright (C) 2011 Marcin Kościelnicki <koriakin@0x04.net>
 * All Rights Reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * VA LINUX SYSTEMS AND/OR ITS SUPPLIERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
 * OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

%{
#include "util.h"
#include "ed2_misc.h"
#include "yy.h"
#include "ed2a.h"
#include "ed2a_parse.h"
#include "ed2a_lex.h"
#include <stdio.h>
void ed2a_error (YYLTYPE *loc, yyscan_t lex_state, void (*fun) (struct ed2a_insn *insn, void *parm), void *parm, struct ed2a_file **res, char const *err) {
	fprintf (stderr, LOC_FORMAT(*loc, "%s\n"), err);
}

%}

%locations
%define api.pure
%name-prefix "ed2a_"
%lex-param { yyscan_t lex_state }
%parse-param { yyscan_t lex_state }
%parse-param { void (*fun) (struct ed2a_insn *insn, void *parm) }
%parse-param { void *parm }
%parse-param { struct ed2a_file **res }

%union {
	uint64_t num;
	char *str;
	struct ed2a_expr *expr;
	struct ed2a_file *file;
	struct ed2a_insn *insn;
	struct ed2a_ipiece *ipiece;
	struct ed2a_iop *iop;
	struct ed2a_rvec *rvec;
	struct ed2a_swz *swz;
	struct ed2_astr astr;
	struct {
		char **mods;
		int modsnum;
		int modsmax;
	} mods;
	struct {
		struct ed2a_expr **prefs;
		int prefsnum;
		int prefsmax;
	} prefs;
}

/* XXX: destructors */

%token <str> T_WORD
%token <str> T_WORDC
%token <str> T_HASHWORD
%token <str> T_WORDLB
%token <str> T_REG
%token <astr> T_STR
%token <num> T_NUM
%token T_ERR
%token T_UMINUS
%token T_PLUSPLUS
%token T_MINUSMINUS
%token T_PLUSEQ
%token T_MINUSEQ

%type <file> file
%type <insn> line
%type <insn> insn
%type <ipiece> ipiece
%type <ipiece> ipiecenp
%type <ipiece> ipiecenpnm
%type <iop> iop
%type <rvec> rvec
%type <str> mems
%type <expr> expr
%type <expr> expr4
%type <expr> expr5
%type <expr> expr6
%type <expr> expr7
%type <swz> swzspec
%type <swz> swzspecs
%type <mods> mods
%type <prefs> prefs

%destructor { if (!fun) ed2a_del_file($$); } <file>
%destructor { ed2a_del_insn($$); } <insn>
%destructor { ed2a_del_ipiece($$); } <ipiece>
%destructor { ed2a_del_iop($$); } <iop>
%destructor { ed2a_del_expr($$); } <expr>
%destructor { ed2a_del_rvec($$); } <rvec>
%destructor { ed2a_del_swz($$); } <swz>
%destructor { free($$); } <str>
%destructor { free($$.str); } <astr>

%%

start:	file				{ *res = $1; }
;

file:	file line			{ $$ = $1; if (!fun) { if ($2) ADDARRAY($$->insns, $2); else $$->broken = 1; } else { if ($2) fun($2, parm); } }
|	file '\n'			{ $$ = $1; }
|	/**/				{ if (!fun) $$ = calloc(sizeof *$$, 1); }
;

line:	insn ';'
|	insn '\n'
|	T_WORDC				{ $$ = ed2a_make_label_insn($1); $$->loc = @$; }
|	error '\n'			{ $$ = 0; }
|	error ';'			{ $$ = 0; }
;

insn:	ipiece				{ $$ = calloc (sizeof *$$, 1); ADDARRAY($$->pieces, $1); $$->loc = @$; }
|	insn '&' '\n' ipiece		{ $$ = $1; ADDARRAY($$->pieces, $4); $$->loc = @$; }
|	insn '\n' '&' ipiece		{ $$ = $1; ADDARRAY($$->pieces, $4); $$->loc = @$; }
|	insn '&' ipiece			{ $$ = $1; ADDARRAY($$->pieces, $3); $$->loc = @$; }
;

prefs:	/**/				{ $$.prefs = 0; $$.prefsnum = 0; $$.prefsmax = 0; }
|	prefs expr			{ $$ = $1; ADDARRAY($$.prefs, $2); }
;

ipiece:	prefs ipiecenp			{ $$ = $2; $$->prefs = $1.prefs; $$->prefsnum = $1.prefsnum; $$->prefsmax = $1.prefsmax; $$->loc = @$; }
;

ipiecenp: ipiecenpnm mods		{ $$ = $1; $$->mods = $2.mods; $$->modsnum = $2.modsnum; $$->modsmax = $2.modsmax; }
;

ipiecenpnm:	T_WORD			{ $$ = calloc (sizeof *$$, 1); $$->name = $1; $$->loc = @$; }
|	ipiecenpnm iop			{ $$ = $1; ADDARRAY($$->iops, $2); $$->loc = @$; }
;

mods:	/**/				{ $$.mods = 0; $$.modsnum = 0; $$.modsmax = 0; }
|	mods T_WORD			{ $$ = $1; ADDARRAY($$.mods, $2); }
;

iop:	mods expr			{ $$ = calloc (sizeof *$$, 1); $$->mods = $1.mods; $$->modsnum = $1.modsnum; $$->modsmax = $1.modsmax; ADDARRAY($$->exprs, $2); $$->loc = @$; }
|	iop '|' expr			{ $$ = $1; ADDARRAY($$->exprs, $3); $$->loc = @$; }
;

expr:	expr4
;

expr4:	expr4 '+' expr5			{ $$ = ed2a_make_expr_bi(ED2A_ET_PLUS, $1, $3); $$->loc = @$; }
|	expr4 '-' expr5			{ $$ = ed2a_make_expr_bi(ED2A_ET_MINUS, $1, $3); $$->loc = @$; }
|	expr5
;

expr5:	expr5 '*' expr6			{ $$ = ed2a_make_expr_bi(ED2A_ET_MUL, $1, $3); $$->loc = @$; }
|	expr6
;

expr6:	T_UMINUS expr6			{ $$ = ed2a_make_expr_bi(ED2A_ET_UMINUS, $2, 0); $$->loc = @$; }
|	expr7
;

expr7:	expr7 '.' swzspec		{ $$ = ed2a_make_expr_swz($1, $3); $$->loc = @$; }
|	expr7 '.' '(' swzspecs ')'	{ $$ = ed2a_make_expr_swz($1, $4); $$->loc = @$; }
|	'#'				{ $$ = ed2a_make_expr(ED2A_ET_DISCARD); $$->loc = @$; }
|	'(' expr ')'			{ $$ = $2; }
|	'(' ipiecenp ')'		{ $$ = ed2a_make_expr_ipiece($2); $$->loc = @$; }
|	mems expr ']'			{ $$ = ed2a_make_expr_mem(ED2A_ET_MEM, $1, $2, 0); $$->loc = @$; }
|	mems expr T_PLUSPLUS expr ']'	{ $$ = ed2a_make_expr_mem(ED2A_ET_MEMPOSTI, $1, $2, $4); $$->loc = @$; }
|	mems expr T_MINUSMINUS expr ']'	{ $$ = ed2a_make_expr_mem(ED2A_ET_MEMPOSTD, $1, $2, $4); $$->loc = @$; }
|	mems expr T_PLUSEQ expr ']'	{ $$ = ed2a_make_expr_mem(ED2A_ET_MEMPREI, $1, $2, $4); $$->loc = @$; }
|	mems expr T_MINUSEQ expr ']'	{ $$ = ed2a_make_expr_mem(ED2A_ET_MEMPRED, $1, $2, $4); $$->loc = @$; }
|	T_HASHWORD			{ $$ = ed2a_make_expr_str(ED2A_ET_LABEL, $1); $$->loc = @$; }
|	T_NUM				{ $$ = ed2a_make_expr_num($1); $$->loc = @$; }
|	T_NUM ':' T_NUM			{ $$ = ed2a_make_expr_num2($1, $3); $$->loc = @$; }
|	T_REG				{ $$ = ed2a_make_expr_str(ED2A_ET_REG, $1); $$->loc = @$; }
|	T_REG ':' T_REG			{ $$ = ed2a_make_expr_reg2($1, $3); $$->loc = @$; }
|	'{' rvec '}'			{ $$ = ed2a_make_expr_rvec($2); $$->loc = @$; }
|	T_STR				{ $$ = ed2a_make_expr_str(ED2A_ET_STR, $1.str); $$->num = $1.len; $$->loc = @$; }
;

rvec:	rvec T_REG			{ $$ = $1; ADDARRAY($$->elems, $2); }
|	rvec '#'			{ $$ = $1; ADDARRAY($$->elems, 0); }
|	/**/				{ $$ = calloc (sizeof *$$, 1); }
;

swzspecs:	swzspecs swzspec	{ $$ = ed2a_make_swz_cat($1, $2); if (!$$) YYERROR; }
|	/**/				{ $$ = ed2a_make_swz_empty(); }
;

swzspec:	T_WORD			{ $$ = ed2a_make_swz_str($1); if (!$$) YYERROR; }
|	T_NUM				{ $$ = ed2a_make_swz_num($1); }
;

mems:	'['				{ $$ = 0; }
|	T_WORDLB			{ $$ = $1; }
;


%%

struct ed2a_file *ed2a_read_file (FILE *file, const char *filename, void (*fun) (struct ed2a_insn *insn, void *parm), void *parm) {
	struct ed2a_file *res;
	yyscan_t lex_state;
	struct yy_lex_intern lex_extra;
	lex_extra.line = 1;
	lex_extra.pos = 1;
	lex_extra.ws = 0;
	lex_extra.file = filename;
	lex_extra.nest = 0;
	ed2a_lex_init_extra(lex_extra, &lex_state);
	ed2a_set_in(file, lex_state);
	ed2a_parse(lex_state, fun, parm, &res);
	ed2a_lex_destroy(lex_state);
	return res;
}