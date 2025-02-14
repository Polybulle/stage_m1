%{
  open AstML
  open HelpersML
  open Autobill.Misc  
;;
%}
%token EOF
%token <int>Lint
%token <bool>Lbool
%token <string>LBasicIdent LConstructorIdent LVarType
%token <AstML.pre_etype>LParseType


%token LOpenPar LClosePar
%token LSemiColon LDoubleSemiColon LRightAngleBraket LLeftAngleBraket
%token LTupleInfixe LConsInfixe 
%token LSimpleArrow
%token LLet LFun LIn LType LRec LOf LMatch LWith LUnderScore LIf LThen LElse

%token LDo LPure LReturn LOpenCurly LCloseCurly LLeftArrow LAssign LFor LBreak LContinue
//%token LGet LSet LRunST LLiftST
%token LSt LExn LM LOpenBracket LCloseBracket

%token LEqual LInf LMult LOr LTOr LTAnd LAnd LAdd LDiv LModulo LSub LNot

%start <prog> prog
%%


%inline variable:
|var = LBasicIdent {
  { basic_ident = var;
    vloc = position $startpos(var) $endpos(var) 
  }
}

prog:
| result = separated_nonempty_list(LDoubleSemiColon,prog_node) ; EOF{
  result
}


prog_node:
| e = expr {Expr e}
| d = def {Def d}

def:
| LLet; var = variable ; LEqual; init = expr{
  {
    dloc = position $startpos($1) $endpos(init);
    dnode = VariableDef{
      var = var;
      init = init
    }
  }
}
| LLet; var = variable; args = nonempty_list(variable);  LEqual; body = expr{
  { dloc = position $startpos($1) $endpos(body);
    dnode = VariableDef{
              var
              ; init = func_curryfy args body   
    }   
  }
}
| LLet;LRec; var = variable; args = nonempty_list(variable);  LEqual; body = expr{

    { dloc = position $startpos($1) $endpos(body);
      dnode = VariableDef{
                var
              ; init = func_rec var args body   
      }   
    }  
}
| LType; parameters = list(LVarType);basic_ident = LBasicIdent ; LEqual ; 
  option(LOr) ;constructors = separated_nonempty_list(LOr,newconstructor_case){
    { dloc = position $startpos($1) $endpos(basic_ident);
      dnode = TypeDef{
      basic_ident; 
      parameters;
      constructors
    }   
  }
  }

newconstructor_case:
| constructor_ident = LConstructorIdent{
  { constructor_ident
  ; c_of = []
  ; loc = position $startpos(constructor_ident) $endpos(constructor_ident)
  }
}
| constructor_ident = LConstructorIdent; LOf ; etype_ls = separated_list(LMult,etype){
  { constructor_ident
  ; c_of = etype_ls
  ; loc = position $startpos(constructor_ident) $endpos(constructor_ident)
  }
}

%inline litteral:
| nb = Lint { Integer nb }
| b = Lbool { Boolean b}
| LOpenPar;LClosePar {Unit}

expr:
| LOpenPar; e = expr ; LClosePar {e}
| const = litteral {
  { enode = Litteral const
  ; eloc = position $startpos(const) $endpos(const)
  }
}
| var = variable {
  { enode = Variable var
  ; eloc = position $startpos(var) $endpos(var)
  }
}
 | LOpenPar;op = unaryoperator ; arg = option(expr); LClosePar{
  { enode = CallUnary {op;arg}
  ; eloc = position $startpos(op) $endpos(arg)
  }
}
| LOpenPar ; arg1 = option(expr) ; op = binaryoperator ; arg2 = option(expr);LClosePar {
  { enode = CallBinary {op;args = List.filter_map (fun x -> x)[arg1;arg2]}
  ; eloc = position $startpos(arg1) $endpos(arg2)
  }
} 
| LOpenPar ; func = expr ; args = nonempty_list(expr) ; LClosePar {
    call_curryify func args
}
| LOpenPar ; hd = expr ; LSemiColon; tail = separated_nonempty_list(LSemiColon,expr);LClosePar {
  { enode = Sequence (hd::tail)
  ; eloc = position $startpos(hd) $endpos(tail)
  }
}
| LLet ; var = variable; LEqual; init = expr ; LIn ; content = expr{
  { enode = Binding {var;init;content}
  ; eloc = position $startpos($1) $endpos(content)
  }
}
 | LFun;args = list(variable);LSimpleArrow;body = expr {
    let args = if List.length args <> 0 then args 
          else [
                { basic_ident = generate_name ();
                  vloc = position $startpos(args) $endpos(args) 
                }
          ] in
   func_curryfy args body
} 
| LOpenPar ; hd = expr ; LTupleInfixe; tail = separated_nonempty_list(LTupleInfixe,expr);LClosePar  {
  { enode = Tuple (hd::tail)
  ; eloc = position $startpos(hd) $endpos(tail)
  }
}
| LOpenPar ; hd = expr ; LConsInfixe; tail = separated_nonempty_list(LConsInfixe,expr);LClosePar  {
    let last,rem = list_getlast_rem tail in
    List.fold_right
    (fun elem acc ->
      { enode = Construct { constructor_ident = "Cons"; to_group = [ elem; acc ] }
      ; eloc = elem.eloc
      }
    )
    (hd::rem) last
}

 | LLeftAngleBraket ; togrp = separated_list(LSemiColon,expr) ; LRightAngleBraket  {
  List.fold_right
    (fun a acc ->
      { enode = Construct { constructor_ident = "Cons"; to_group = [ a; acc ] }
      ; eloc = position $startpos(togrp) $endpos(togrp)
      })
    togrp
    { enode = Construct { constructor_ident = "Nil"; to_group = [] }
    ; eloc = position $startpos($3) $endpos($3)
    }
} 

| constructor_ident =  LConstructorIdent; LOpenPar ; togrp = separated_list(LTupleInfixe,expr);LClosePar {
  { 
    enode = Construct { constructor_ident ; to_group = togrp }
  ; eloc = position $startpos(togrp) $endpos(togrp)
  }
}
| constructor_ident =  LConstructorIdent  {
  {
    enode = Construct { constructor_ident ; to_group = [] }
  ; eloc = position $startpos(constructor_ident) $endpos(constructor_ident)
  }
}

| LLet; var = variable; args = nonempty_list(variable);  LEqual; func_body = expr; LIn ;content = expr{
    { enode = Binding {
      var ; init = func_curryfy args func_body
      ; content}
      ; eloc = position $startpos($1) $endpos(content)
  }
}
| LLet ; LRec; var = variable; args = nonempty_list(variable);  LEqual; func_body = expr; LIn ;content = expr{
    { enode = Binding {
            var ; init = func_rec var args func_body
            ; content}
    ; eloc = position $startpos($1) $endpos(content)
  }
}
| LOpenPar;LMatch ; e = expr ;LWith ;option(LOr) ; cases = separated_nonempty_list(LOr,match_case);LClosePar{
   { 
      enode =  Match{ to_match = e ; cases}
    ; eloc = position $startpos($1) $endpos(cases)
  }
}
| LIf ; cond = expr ; LThen ; iftrue = expr ; LElse ; iffalse = expr {
  { enode = Match{ to_match = cond ; 
      cases = [
        { pattern = { pnode = LitteralPattern (Boolean true)
                    ; ploc = iftrue.eloc
                    }
        ; consequence = iftrue
        ; cloc = iftrue.eloc
        }
      ; { pattern = { pnode = LitteralPattern (Boolean false)
                    ; ploc = iffalse.eloc
                    }
        ; consequence = iffalse
        ; cloc = iffalse.eloc
        }
      ]
  }
  ; eloc = position $startpos($1) $endpos(iffalse)
  }
} 

| LDo ; LOpenCurly ; b = block ; LCloseCurly {
  { enode = Do b;
    eloc = position $startpos($1) $endpos($4)
  }
}

effect:
| LSt LOpenPar s = etype LSemiColon eff = effect
  { State (s, eff) }

| LExn LOpenPar e = etype LSemiColon eff = effect
  { Except (e, eff) }

| LM
  { Ground }

block:
| LPure e = expr ; LSemiColon? {
  { snode = Stmt_return e;
    sloc = position $startpos(e) $endpos(e)
  }
}

| LLet x = variable; LLeftArrow ; LOpenCurly s = block LCloseCurly ; LSemiColon; rest = block {
  { snode = Stmt_let (x,s,rest);
    sloc = position $startpos($1) $endpos(rest)
  }
}

| LLet x = variable; LLeftArrow ; e = expr ; LSemiColon; rest = block {
  let s = {snode = Stmt_return e; sloc = position $startpos(e) $endpos(e)} in
  { snode = Stmt_let (x,s,rest)
  ; sloc = position $startpos($1) $endpos(rest)
  }
}

| LLet x = variable LAssign e = expr LSemiColon rest = block {
  { snode = Stmt_mut (x,e,rest);
    sloc = position $startpos($1) $endpos(rest)
  }
}

| x = variable LAssign e = expr LSemiColon rest = block {
  { snode = Stmt_mut_change_set(x,e,rest);
    sloc = position $startpos(x) $endpos(e)
  }
}

| LIf e = expr LThen s1 = block LElse s2 = block {
  { snode = Stmt_if (e,s1,s2);
    sloc = position $startpos($1) $endpos(s2)
  }
}

| LReturn ; e = expr {
  { snode = Stmt_early_return (e);
    sloc = position $startpos($1) $endpos(e)
  }
}

| LFor ; x = variable ; LIn ; e = expr ; LDo ; LOpenCurly ; s = block ; LCloseCurly {
  { snode = Stmt_for (x,e,s);
    sloc = position $startpos($1) $endpos($8)
  }
}

| LBreak {
  { snode = Stmt_break
  ; sloc = position $startpos($1) $endpos($1)
  }
}

| LContinue {
  { snode = Stmt_continue
  ; sloc = position $startpos($1) $endpos($1)
  }
}


match_case :
| pattern = pattern ;LSimpleArrow; consequence = expr{
    { pattern ; consequence ; 
    cloc = position $startpos(pattern) $endpos(consequence)}
}


pattern :
| LOpenPar ; p = pattern ; LClosePar {p}
| l = litteral  {
    { pnode = LitteralPattern l
    ; ploc = position $startpos(l) $endpos(l)
    }
  }
| ident = LBasicIdent {
  { pnode = VarPattern ident
  ; ploc = position $startpos(ident) $endpos(ident)
  }
}
| LUnderScore {
  { pnode = WildcardPattern
  ; ploc = position $startpos($1) $endpos($1)
  }
}

| LLeftAngleBraket ; togrp = separated_list(LSemiColon,pattern) ; LRightAngleBraket  {
  List.fold_right
    (fun a acc ->
      { pnode = ConstructorPattern { constructor_ident = "Cons"; content = [ a; acc ] }
      ; ploc = position $startpos(togrp) $endpos(togrp)
      })
    togrp
    { pnode = ConstructorPattern { constructor_ident = "Nil"; content = [] }
    ; ploc = position $startpos($3) $endpos($3)
    }
} 
| constructor_ident = LConstructorIdent {
  { pnode = ConstructorPattern
      { constructor_ident
      ; content = []
      }
  ; ploc = position $startpos(constructor_ident) $endpos(constructor_ident)
  }
}
| constructor_ident = LConstructorIdent; LOpenPar; togrp = separated_list(LTupleInfixe,pattern);LClosePar {
  { pnode = ConstructorPattern
      { constructor_ident
      ; content = togrp
      }
  ; ploc = position  $startpos(togrp) $endpos(togrp)
  }
  
}
| LOpenPar ; hd = pattern ; LTupleInfixe; tail = separated_nonempty_list(LTupleInfixe,pattern);LClosePar  {
  { pnode = TuplePattern (hd::tail)
  ; ploc =  position $startpos(hd) $endpos(tail)
  }
}
| LOpenPar ; hd = pattern ; LConsInfixe; tail = separated_nonempty_list(LConsInfixe,pattern);LClosePar  {
    let last,rem = list_getlast_rem tail in
    List.fold_right
    (fun elem acc ->
      { pnode = ConstructorPattern { constructor_ident = "Cons"; content = [ elem; acc ] }
      ; ploc = elem.ploc
      }
    )
    (hd::rem) last
}


%inline unaryoperator:
|LNot { Autobill.Lcbpv.Not }

%inline binaryoperator:
|LSub { Autobill.Lcbpv.Subs }
|LDiv { Autobill.Lcbpv.Div }
|LMult { Autobill.Lcbpv.Mult }
|LModulo { Autobill.Lcbpv.Mod }
|LAdd { Autobill.Lcbpv.Add }
|LAnd;LAnd { Autobill.Lcbpv.And }
|LOr;LOr {Autobill.Lcbpv.Or}
|LTOr {Autobill.Lcbpv.Or}
|LTAnd { Autobill.Lcbpv.And }
|LEqual {Autobill.Lcbpv.Int_Eq}
|LInf;LEqual {Autobill.Lcbpv.Int_Leq}
|LInf {Autobill.Lcbpv.Int_Lt}



etype:
| etype = LParseType {
   {  etype
    ; tloc = position $startpos(etype) $endpos(etype)
  }
} 
| LOpenPar; t = etype ; LClosePar {t}
| LOpenPar ; hd = etype ; LMult; tail = separated_nonempty_list(LMult,etype);LClosePar{
    { etype = TypeTuple (hd::tail)
    ; tloc = position $startpos(hd) $endpos(tail)
    }
}
| LOpenPar;args = nonempty_list(etype)
  ;LSimpleArrow;return_type = etype;LClosePar {
    functype_curryfy args return_type
}
| t = LVarType {
  { etype = TypeVar t
  ; tloc = position $startpos(t) $endpos(t)
  }
}
| t = LBasicIdent {
  { etype = TypeDefined t
  ; tloc = position $startpos(t) $endpos(t)
  }
} 
| LOpenPar; hd = etype ;tail = nonempty_list(etype);  LClosePar{
  let last,rem = list_getlast_rem (hd::tail) in
  { etype = TypeConstructor {to_build = last; parameters = rem}
  ; tloc = position $startpos(hd) $endpos(tail)
  }
  }
| LM ; LOpenBracket;  eff = effect ; LCloseBracket;  LOpenPar;  t = etype;  LClosePar
    { {
        etype = TypeMonadic (eff,t);
        tloc = position $startpos($1) $endpos($7)
       }
    }
