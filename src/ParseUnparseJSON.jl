module ParseUnparseJSON
    export GrammarSymbolKinds, ParserIdents
    module GrammarSymbolKinds
        export GrammarSymbolKind, grammar_symbol_error_kinds
        using ParseUnparse.KindConstruction
        struct GrammarSymbolKind
            opaque::UInt8
            const global kind_to_name = Dict{GrammarSymbolKind, String}()
            const global name_to_kind = Dict{String, GrammarSymbolKind}()
            next_opaque::UInt8 = 0x0
            function constructor_helper()
                opaque = next_opaque
                next_opaque = Base.checked_add(opaque, oftype(opaque, 1))
                new(opaque)
            end
            function GrammarSymbolKind(name::String)
                construct_kind!(constructor_helper, kind_to_name, name_to_kind, name)
            end
        end
        function Base.show(io::IO, kind::GrammarSymbolKind)
            if !haskey(kind_to_name, kind)
                throw(ArgumentError("unrecognized grammar symbol kind"))
            end
            print(io, kind_to_name[kind])
        end
        # terminal symbols
        const number = GrammarSymbolKind("number")
        const keyword = GrammarSymbolKind("keyword")  # either `null`, `false` or `true`
        const string = GrammarSymbolKind("string")
        const dictionary_delimiter_left = GrammarSymbolKind("dictionary_delimiter_left")
        const dictionary_delimiter_right = GrammarSymbolKind("dictionary_delimiter_right")
        const list_delimiter_left = GrammarSymbolKind("list_delimiter_left")
        const list_delimiter_right = GrammarSymbolKind("list_delimiter_right")
        const list_element_separator = GrammarSymbolKind("list_element_separator")
        const pair_element_separator = GrammarSymbolKind("pair_element_separator")
        # nonterminal symbols
        const pair = GrammarSymbolKind("pair")  # "member"
        const optional_incomplete_dictionary = GrammarSymbolKind("optional_incomplete_dictionary")
        const dictionary = GrammarSymbolKind("dictionary")  # "members"
        const delimited_dictionary = GrammarSymbolKind("delimited_dictionary")  # "object"
        const optional_incomplete_list = GrammarSymbolKind("optional_incomplete_list")
        const list = GrammarSymbolKind("list")  # "elements"
        const delimited_list = GrammarSymbolKind("delimited_list")  # "array"
        const value = GrammarSymbolKind("value")
        # not part of the grammar, error in lexing/tokenization
        const lexing_error_unknown = GrammarSymbolKind("lexing_error_unknown")
        const lexing_error_expected_keyword = GrammarSymbolKind("lexing_error_expected_keyword")
        const lexing_error_expected_string = GrammarSymbolKind("lexing_error_expected_string")
        const lexing_error_expected_number = GrammarSymbolKind("lexing_error_expected_number")
        const grammar_symbol_error_kinds = (
            lexing_error_unknown,
            lexing_error_expected_keyword,
            lexing_error_expected_string,
            lexing_error_expected_number,
        )
    end
    module TokenIterators
        export TokenIterator
        using ParseUnparse.LexingUtil, ..GrammarSymbolKinds
        struct TokenIterator{T}
            character_iterator::T
            function TokenIterator(character_iterator)
                new{typeof(character_iterator)}(character_iterator)
            end
        end
        function Base.IteratorSize(::Type{<:TokenIterator})
            Base.SizeUnknown()
        end
        const significant_characters = (;
            general = (;
                whitespace = ('\t', '\n', '\r', ' '),
                list_element_separator = (',',),
                pair_element_separator = (':',),
                dictionary_delimiter_left = ('{',),
                dictionary_delimiter_right = ('}',),
                list_delimiter_left = ('[',),
                list_delimiter_right = (']',),
                double_quote = ('"',),
                decimal_digit = ('0' : '9'),
                minus = ('-',),
                alpha_lower = ('a' : 'z'),
                alpha_upper = ('A' : 'Z'),
            ),
            string = (;
                escaper = ('\\',),
                may_appear_unescaped_1 = (' ', Char(Int('"') - 1)),
                may_appear_unescaped_2 = (Char(Int('"') + 1) : Char(Int('\\') - 1)),
                may_appear_unescaped_3 = (Char(Int('\\') + 1) : '\U10ffff'),
                may_appear_escaped = ('"', '\\', '/', 'b', 'f', 'n', 'r', 't'),
                may_appear_escaped_u = ('u',),
                hex_alpha_digit_lower = ('a' : 'f'),
                hex_alpha_digit_upper = ('A' : 'F'),
            ),
            number = (;
                e = ('e', 'E'),
                decimal_digit_zero = ('0',),
                decimal_digit_nonzero = ('1' : '9'),
                decimal_separator = ('.',),
                sign = ('-', '+'),
            ),
        )
        function character_does_not_need_escaping(c::AbstractChar)
            (c ∈ significant_characters.string.may_appear_unescaped_1) ||
            (c ∈ significant_characters.string.may_appear_unescaped_2) ||
            (c ∈ significant_characters.string.may_appear_unescaped_3)
        end
        function character_is_keyword(c::AbstractChar)
            (c ∈ significant_characters.general.alpha_lower) ||
            (c ∈ significant_characters.general.alpha_upper)
        end
        function character_is_number_start(c::AbstractChar)
            (c ∈ significant_characters.general.minus) ||
            (c ∈ significant_characters.general.decimal_digit)
        end
        function character_is_hex_digit(c::AbstractChar)
            (c ∈ significant_characters.general.decimal_digit) ||
            (c ∈ significant_characters.string.hex_alpha_digit_lower) ||
            (c ∈ significant_characters.string.hex_alpha_digit_upper)
        end
        function lex_keyword!(lexer_state)
            buf = lexer_state_get_extra(lexer_state)
            while true
                if (
                    isempty(lexer_state_peek!(lexer_state)) ||
                    !character_is_keyword(only(lexer_state_peek!(lexer_state)))
                )
                    break
                end
                print(buf, only(lexer_state_consume!(lexer_state)))
            end
            if String(take!(buf)) ∈ ("true", "false", "null")
                GrammarSymbolKinds.keyword
            else
                GrammarSymbolKinds.lexing_error_expected_keyword
            end
        end
        function lex_string!(lexer_state)
            # Minimized DFA:
            #
            # * eight states
            #
            # * 'c' stand for any Unicode character between '\U20' and '\U10ffff', except for '"' or '\\'
            #
            # * 'e' stands for '\\'
            #
            # * 'h' stands for any hexadecimal digit character (lowercase and uppercase are both allowed)
            #
            # * https://cyberzhg.github.io/toolbox/min_dfa?regex=IigoKGMpfChlKCJ8ZXwvfGJ8ZnxufHJ8dHwodWhoaGgpKSkpKiki
            ret = GrammarSymbolKinds.string
            # state 1
            let oc = lexer_state_consume!(lexer_state)
                if isempty(oc)
                    @goto string_error
                end
                if only(oc) ∉ significant_characters.general.double_quote
                    @goto string_error
                end
            end
            @label string_state_2
            let oc = lexer_state_consume!(lexer_state)
                if isempty(oc)
                    @goto string_error
                end
                c = only(oc)
                if character_does_not_need_escaping(c)
                    @goto string_state_2
                end
                if c ∈ significant_characters.general.double_quote
                    @goto string_done  # state 3 is an accepting state (the only one) and has no outwards transitions
                end
                if c ∉ significant_characters.string.escaper
                    @goto string_error
                end
            end
            # state 4
            let oc = lexer_state_consume!(lexer_state)
                if isempty(oc)
                    @goto string_error
                end
                c = only(oc)
                if c ∈ significant_characters.string.may_appear_escaped
                    @goto string_state_2
                end
                if c ∉ significant_characters.string.may_appear_escaped_u
                    @goto string_error
                end
            end
            # states 5 to 8 are merged into a single `for` loop
            for _ ∈ 1:4
                oc = lexer_state_consume!(lexer_state)
                if isempty(oc)
                    @goto string_error
                end
                if !character_is_hex_digit(only(oc))
                    @goto string_error
                end
            end
            @goto string_state_2
            @label string_error
            ret = GrammarSymbolKinds.lexing_error_expected_string
            @label string_done
            ret
        end
        function lex_number!(lexer_state)
            # Minimized DFA:
            #
            # * nine states
            #
            # * 'a' stands for any digit between '1' and '9'
            #
            # * 'p' stands for '+'
            #
            # * https://cyberzhg.github.io/toolbox/min_dfa?regex=KC0/KCgwfGEpfChhKCgwfGEpKykpKSkoKC4oKDB8YSkrKSk/KSgoKGV8RSkoKHB8LSk/KSgoMHxhKSspKT8p
            ret = GrammarSymbolKinds.number
            # state 1
            let oc = lexer_state_consume!(lexer_state)
                if isempty(oc)
                    @goto number_error
                end
                c = only(oc)
                if c ∈ significant_characters.number.decimal_digit_zero
                    @goto number_state_3
                end
                if c ∈ significant_characters.number.decimal_digit_nonzero
                    @goto number_state_4
                end
                if c ∉ significant_characters.general.minus
                    @goto number_error
                end
            end
            # state 2
            let oc = lexer_state_consume!(lexer_state)
                if isempty(oc)
                    @goto number_error
                end
                c = only(oc)
                if c ∈ significant_characters.number.decimal_digit_nonzero
                    @goto number_state_4
                end
                if c ∉ significant_characters.number.decimal_digit_zero
                    @goto number_error
                end
            end
            @label number_state_3  # accepting state
            let oc = lexer_state_peek!(lexer_state)
                if isempty(oc)
                    @goto number_done
                end
                c = only(oc)
                c_is_decimal_separator = c ∈ significant_characters.number.decimal_separator
                if c_is_decimal_separator || (c ∈ significant_characters.number.e)
                    lexer_state_consume!(lexer_state)
                    if c_is_decimal_separator
                        @goto number_state_5
                    end
                    @goto number_state_6
                end
            end
            @goto number_done
            @label number_state_4  # accepting state
            let oc = lexer_state_peek!(lexer_state)
                if isempty(oc)
                    @goto number_done
                end
                c = only(oc)
                c_is_decimal_digit = c ∈ significant_characters.general.decimal_digit
                c_is_decimal_separator = c ∈ significant_characters.number.decimal_separator
                if c_is_decimal_digit || c_is_decimal_separator || (c ∈ significant_characters.number.e)
                    lexer_state_consume!(lexer_state)
                    if c_is_decimal_digit
                        @goto number_state_4
                    end
                    if c_is_decimal_separator
                        @goto number_state_5
                    end
                    @goto number_state_6
                end
            end
            @goto number_done
            @label number_state_5
            let oc = lexer_state_consume!(lexer_state)
                if isempty(oc)
                    @goto number_error
                end
                if only(oc) ∉ significant_characters.general.decimal_digit
                    @goto number_error
                end
            end
            @label number_state_7  # accepting state
            let oc = lexer_state_peek!(lexer_state)
                if isempty(oc)
                    @goto number_done
                end
                c = only(oc)
                c_is_decimal_digit = c ∈ significant_characters.general.decimal_digit
                if c_is_decimal_digit || (c ∈ significant_characters.number.e)
                    lexer_state_consume!(lexer_state)
                    if c_is_decimal_digit
                        @goto number_state_7
                    end
                    @goto number_state_6
                end
            end
            @goto number_done
            @label number_state_6
            let oc = lexer_state_consume!(lexer_state)
                if isempty(oc)
                    @goto number_error
                end
                c = only(oc)
                if c ∈ significant_characters.general.decimal_digit
                    @goto number_state_9
                end
                if c ∉ significant_characters.number.sign
                    @goto number_error
                end
            end
            # state 8
            let oc = lexer_state_consume!(lexer_state)
                if isempty(oc)
                    @goto number_error
                end
                if only(oc) ∉ significant_characters.general.decimal_digit
                    @goto number_error
                end
            end
            @label number_state_9  # accepting state
            let oc = lexer_state_peek!(lexer_state)
                if isempty(oc)
                    @goto number_done
                end
                if only(oc) ∈ significant_characters.general.decimal_digit
                    lexer_state_consume!(lexer_state)
                    @goto number_state_9
                end
            end
            @goto number_done
            @label number_error
            ret = GrammarSymbolKinds.lexing_error_expected_number
            @label number_done
            ret
        end
        function Base.iterate(
            token_iterator::TokenIterator,
            token_iterator_state::TokenIteratorState{IOBuffer, Char} = token_iterator_state_init(Char, IOBuffer(; read = false)),
        )
            if token_iterator_state.is_done
                nothing
            else
                let symbol_kind
                    lexer_state = let o = lexer_state_new(token_iterator_state.opaque, token_iterator_state.extra, token_iterator.character_iterator)
                        if o === ()
                            return nothing
                        end
                        only(o)
                    end
                    initial_consumed_character_count = lexer_state_get_consumed_character_count(lexer_state)
                    have_token = false
                    while !isempty(lexer_state_peek!(lexer_state))
                        if only(lexer_state_peek!(lexer_state)) ∈ significant_characters.general.whitespace
                            lexer_state_consume!(lexer_state)
                        else
                            have_token = true
                            symbol_kind = if character_is_keyword(only(lexer_state_peek!(lexer_state)))
                                lex_keyword!(lexer_state)
                            elseif only(lexer_state_peek!(lexer_state)) ∈ significant_characters.general.double_quote
                                lex_string!(lexer_state)
                            elseif character_is_number_start(only(lexer_state_peek!(lexer_state)))
                                lex_number!(lexer_state)
                            else
                                let c = only(lexer_state_consume!(lexer_state))
                                    if c ∈ significant_characters.general.list_element_separator
                                        GrammarSymbolKinds.list_element_separator
                                    elseif c ∈ significant_characters.general.pair_element_separator
                                        GrammarSymbolKinds.pair_element_separator
                                    elseif c ∈ significant_characters.general.list_delimiter_left
                                        GrammarSymbolKinds.list_delimiter_left
                                    elseif c ∈ significant_characters.general.list_delimiter_right
                                        GrammarSymbolKinds.list_delimiter_right
                                    elseif c ∈ significant_characters.general.dictionary_delimiter_left
                                        GrammarSymbolKinds.dictionary_delimiter_left
                                    elseif c ∈ significant_characters.general.dictionary_delimiter_right
                                        GrammarSymbolKinds.dictionary_delimiter_right
                                    else
                                        GrammarSymbolKinds.lexing_error_unknown
                                    end
                                end
                            end::GrammarSymbolKind
                            while true  # optional trailing whitespace
                                if (
                                    isempty(lexer_state_peek!(lexer_state)) ||
                                    (only(lexer_state_peek!(lexer_state)) ∉ significant_characters.general.whitespace)
                                )
                                    break
                                end
                                lexer_state_consume!(lexer_state)
                            end
                            break
                        end
                    end
                    if have_token
                        let consumed_character_count = lexer_state_get_consumed_character_count(lexer_state)
                            (; opaque, token_source) = lexer_state_destroy!(lexer_state)
                            source_range_of_token = (initial_consumed_character_count + true):consumed_character_count
                            token = ((source_range_of_token, String(token_source)), symbol_kind)
                            state = (; is_done = symbol_kind ∈ grammar_symbol_error_kinds, extra = token_iterator_state.extra, opaque)
                            (token, state)
                        end
                    else
                        nothing
                    end
                end
            end
        end
    end
    module ParserIdents
        export ParserIdent
        using ParseUnparse.ContextFreeGrammarUtil, ParseUnparse.SymbolGraphs, ParseUnparse.AbstractParserIdents, ..GrammarSymbolKinds, ..TokenIterators
        struct ParserIdent{Debug <: Nothing} <: AbstractParserIdent
        end
        function ParserIdent()
            ParserIdent{Nothing}()
        end
        function get_debug(::ParserIdent{Debug}) where {Debug <: Nothing}
            Debug
        end
        function AbstractParserIdents.get_lexer(::ParserIdent)
            TokenIterator
        end
        function AbstractParserIdents.get_token_grammar(::ParserIdent)
            start_symbol = GrammarSymbolKinds.value
            grammar = Dict{GrammarSymbolKind, Set{Vector{GrammarSymbolKind}}}(
                (GrammarSymbolKinds.value => Set(([GrammarSymbolKinds.number], [GrammarSymbolKinds.string], [GrammarSymbolKinds.keyword], [GrammarSymbolKinds.delimited_list], [GrammarSymbolKinds.delimited_dictionary]))),
                (GrammarSymbolKinds.delimited_list => Set(([GrammarSymbolKinds.list_delimiter_left, GrammarSymbolKinds.list, GrammarSymbolKinds.list_delimiter_right],))),
                (GrammarSymbolKinds.list => Set(([], [GrammarSymbolKinds.value, GrammarSymbolKinds.optional_incomplete_list]))),
                (GrammarSymbolKinds.optional_incomplete_list => Set(([], [GrammarSymbolKinds.list_element_separator, GrammarSymbolKinds.value, GrammarSymbolKinds.optional_incomplete_list]))),
                (GrammarSymbolKinds.delimited_dictionary => Set(([GrammarSymbolKinds.dictionary_delimiter_left, GrammarSymbolKinds.dictionary, GrammarSymbolKinds.dictionary_delimiter_right],))),
                (GrammarSymbolKinds.dictionary => Set(([], [GrammarSymbolKinds.pair, GrammarSymbolKinds.optional_incomplete_dictionary]))),
                (GrammarSymbolKinds.optional_incomplete_dictionary => Set(([], [GrammarSymbolKinds.list_element_separator, GrammarSymbolKinds.pair, GrammarSymbolKinds.optional_incomplete_dictionary]))),
                (GrammarSymbolKinds.pair => Set(([GrammarSymbolKinds.string, GrammarSymbolKinds.pair_element_separator, GrammarSymbolKinds.value],))),
            )
            (start_symbol, grammar)
        end
        function AbstractParserIdents.get_token_parser(id::ParserIdent)
            (start_symbol, grammar) = get_token_grammar(id)
            tables = make_parsing_table_strong_ll_1(grammar, start_symbol)
            Debug = get_debug(id)
            StrongLL1TableDrivenParser{Debug, Tuple{UnitRange{Int64}, String}}(start_symbol, tables...)
        end
    end
end
