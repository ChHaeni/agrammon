use Agrammon::Formula;
use Agrammon::Formula::Builder;

grammar Agrammon::Formula::Parser {
    rule TOP {
        <.ws>
        <statementlist>
        [ $ || <.panic('Confused')> ]
    }

    rule statementlist {
        <statement>*
    }

    method panic($message) {
        die "$message near " ~ self.orig.substr(self.pos, 50).perl;
    }

    rule statement {
        | <statement_control> ';'?
        | <EXPR>
          <statement_modifier>?
          [';' || <?before '}' | $>]
    }

    proto rule statement_modifier { * }
    rule statement_modifier:sym<when> {
        'when' <EXPR>
    }

    rule EXPR {
        <term> [ <infix> <term> ]*
    }

    proto token statement_control { * }

    rule statement_control:sym<if> {
        'if'
        [ '(' <EXPR> ')' || <.panic('Missing or malformed condition')> ]
        <then=.block>
        [ 'else' <else=.block> ]?
    }

    rule statement_control:sym<given> {
        'given'
        [ '(' <EXPR> ')' || <.panic('Missing or malformed topic')> ]
        <block>
    }

    rule block {
        [ '{' || <.panic('Expected block')> ]
        <statementlist>
        [ '}' || <.panic('Missing } after block')> ]
    }

    proto token term { * }

    rule term:sym<In> {
        'In(' [<symbol=.ident> || <.panic('Bad identifier')>] ')'
    }
    rule term:sym<Tech> {
        'Tech(' [<symbol=.ident> || <.panic('Bad identifier')>] ')'
    }
    rule term:sym<Val> {
        'Val('
            [<symbol=.ident> || <.panic('Bad identifier')>]
            [',' || <.panic('Missing , in Val')>]
            [<module=.name> || <.panic('Missing or malformed module name')>]
        ')'
    }
    rule term:sym<Out> {
        'Out(' [<symbol=.ident> || <.panic('Bad identifier')>] ')'
    }
    rule term:sym<Sum> {
        'Sum('
            [<symbol=.ident> || <.panic('Bad identifier')>]
            [',' || <.panic('Missing , in Sum')>]
            [<module=.name> || <.panic('Missing or malformed module name')>]
        ')'
    }

    rule term:sym<my> {
        'my' <variable>
    }

    rule term:sym<variable> {
        <variable>
    }

    token variable {
        '$' <.ident>
    }

    rule term:sym<return> {
        'return' <EXPR>?
    }

    rule term:sym<defined> {
        'defined' <term>
    }

    rule term:sym<( )> {
        '(' <EXPR> [ ')' || <.panic('Missing closing )')> ]
    }

    token term:sym<integer> {
        \d+
    }

    token term:sym<rational> {
        \d* '.' \d+
    }

    token term:sym<single-string> {
        "'"
        <single-string-piece>*
        ["'" || <.panic('Unterminated string')>]
    }

    proto token single-string-piece { * }
    token single-string-piece:sym<non-esc> {
        <-['\\]>+
    }
    token single-string-piece:sym<esc> {
        '\\'
        [
        | $<escaped>=<[\\']>
        | (.) {} <.panic("Unknown escape \\$0")>
        ]
    }

    proto token infix { * }
    token infix:sym</> { '/' }
    token infix:sym<*> { '*' }
    token infix:sym<+> { '+' }
    token infix:sym<-> { '-' }
    token infix:sym<=> { '=' }
    token infix:sym<< > >> { '>' }
    token infix:sym<< >= >> { '>=' }
    token infix:sym<< < >> { '<' }
    token infix:sym<< <= >> { '<=' }
    token infix:sym<< == >> { '==' }
    token infix:sym<< != >> { '!=' }
    token infix:sym<eq> { 'eq' }
    token infix:sym<ne> { 'ne' }
    token infix:sym<and> { 'and' }
    token infix:sym<or> { 'or' }
    token infix:sym<&&> { '&&' }
    token infix:sym<||> { '||' }

    rule infix:sym<? :> {
        '?' <EXPR> ':'
    }

    token name {
        <name-part> ['::' <name-part>]*
    }

    token name-part {
        <.ident> | '..'
    }

    token ws {
        <!ww>
        [
        || \s+
        || '#' \N+ \n
        ]*
    }
}

sub parse-formula(Str $formula, Str $*CURRENT-MODULE) is export {
    Agrammon::Formula::Parser.parse($formula, actions => Agrammon::Formula::Builder).ast
}