--
-- Project:  LuaIDL
-- Version:  0.6.0b
-- Author:   Ricardo Calheiros <rcosme@tecgraf.puc-rio.br>
-- Last modification: 11/12/2006
-- Filename: sin.lua
-- 

-- OMG IDL Grammar ( Corba v3.0 )
-- LL(1)
--(1)  <specification>          :=    <import_l> <definition_l>
--(2)  <import_l>               :=    <import> <import_l>
--(3)                           |     empty
--(4)  <import>                 :=    TK_IMPORT <imported_scope> ";"
--(5)  <imported_scope>         :=    <scoped_name>
--(6)                           |     TK_STRING_LITERAL
--(7)  <scoped_name>            :=    TK_ID <scoped_name>
--(8)                           |     ":" ":" TK_ID <scoped_name_l>
--(9)  <scoped_name_l>          :=    ":" ":" TK_ID <scoped_name_l>
--(10)                          |     empty
--(11)  <definition_l>          :=    <definition> <definition_l_r>
--(12)  <definition_l_r>        :=    <definition> <definition_l_r>
--(13)                          |     empty
--(14)  <definition>            :=    <type_dcl> ";"
--(15)                          |     <const_dcl> ";"
--(16)                          |     <except_dcl> ";"
--(17)                          |     <inter_value_event> ";"
--(18)                          |     <module> ";"
--(19)                          |     <type_id_dcl> ";"
--(20)                          |     <type_prefix_dcl> ";"
--(21)                          |     <component> ";"
--(22)                          |     <home_dcl> ";"
--(23)  <type_dcl>              :=    "typedef" <type_declarator>
--(24)                          |     <enum_type>
--(25)                          |     TK_NATIVE TK_ID
--(26)                          |     <union_or_struct>
--(27)  <type_declarator>       :=    <type_spec> <declarator_l>
--(28)  <type_spec>             :=    <simple_type_spec>
--(29)                          |     <constr_type_spec>
--(30)  <simple_type_spec>      :=    <base_type_spec>
--(31)                          |     <template_type_spec>
--(32)                          |     <scoped_name>
--(33)  <constr_type_spec>      :=    <struct_type>
--(34)                          |     <union_type>
--(35)                          |     <enum_type>
--(36)  <base_type_spec>        :=    <float_type_or_int_type>
--(37)                          |     TK_CHAR
--                              |     TK_WCHAR **
--(38)                          |     TK_BOOLEAN
--(39)                          |     TK_OCTET
--(40)                          |     TK_ANY
--(41)                          |     TK_OBJECT
--(42)                          |     TK_VALUEBASE
--(43)  <float_type_or_int_type>:=    <floating_pt_type>
--(44)                          |     <integer_type>
--(45)                          |     TK_LONG <long_or_double>
--(46)  <floating_pt_type>      :=    TK_FLOAT
--(47)                          |     TK_DOUBLE
--(48)  <integer_type>          :=    TK_SHORT
--(49)                          |     <unsigned_int>
--(50)  <unsigned_int>          :=    TK_UNSIGNED <unsigned_int_tail>
--(51)  <unsigned_int_tail>     :=    TK_LONG <long_e>
--(52)                          |     TK_SHORT
--(53)  <long_e>                :=    TK_LONG
--(54)                          |     empty
--(55)  <long_or_double>        :=    TK_LONG
--(56)                          |     TK_DOUBLE
--(57)                          |     empty
--(58)  <template_type_spec>    :=    <sequence_type>
--(59)                          |     <string_type>
--                              |     <wide_string_type> **
--(60)                          |     <fixed_pt_type>
--(61)  <sequence_type>         :=    TK_SEQUENCE "<" <simple_type_spec> <sequence_type_tail>
--(69)  <sequence_type_tail>    :=    "," <positive_int_const> ">"
--(70)                          |     ">"
--(71)  <string_type>           :=    TK_STRING <string_type_tail>
--(72)  <string_type_tail>      :=    "<" <positive_int_const> ">"
--(73)                          |     empty
--    <wide_string_type>        :=    TK_WSTRING <string_type_tail> **
--(74)  <fixed_pt_type>         :=    TK_FIXED "<" <positive_int_const> "," <positive_int_const> ">"
--(75)  <positive_int_const>    :=    <xor_expr> <or_expr_l>
--(91)  <or_expr_l>             :=    "|" <xor_expr> <or_expr_l>
--(92)                          |     empty
--(93)  <xor_expr>              :=    <and_expr> <xor_expr_l>
--(94)  <xor_expr_l>            :=    "^" <and_expr> <xor_expr_l>
--(95)                          |     empty
--(96)  <and_expr>              :=    <shift_expr> <and_expr_l>
--(97)  <and_expr_l>            :=    "&" <shift_expr> <and_expr_l>
--(98)                          |     empty
--(99)  <shift_expr>            :=    <add_expr> <shift_expr_l>
--(100) <shift_expr_l>          :=    ">>" <add_expr> <shift_expr_l>
--(101)                         |     "<<" <add_expr> <shift_expr_l>
--(102)                         |     empty
--(103) <add_expr>              :=    <mult_expr> <add_expr_l>
--(104) <add_expr_l>            :=    "+" <mult_expr> <add_expr_l>
--(105)                         |     "-" <mult_expr> <add_expr_l>
--(106)                         |     empty
--(107) <mult_expr>             :=    <unary_expr> <mult_expr_l>
--(108) <mult_expr_l>           :=    "*" <unary_expr> <mult_expr_l>
--(109)                         |     "/" <unary_expr> <mult_expr_l>
--(110)                         |     "%" <unary_expr> <mult_expr_l>
--(111)                         |     empty
--(112) <unary_expr>            :=    <unary_operator> <primary_expr>
--(113)                         |     <primary_expr>
--(114) <unary_operator>        :=    "-"
--(115)                         |     "+"
--(116)                         |     "~"
--(117) <primary_expr>          :=    <scoped_name>
--(118)                         |     <literal>
--(119)                         |     "(" <positive_int_const3> ")"
--(120) <literal>               :=    TK_INTEGER_LITERAL
--(121)                         |     TK_STRING_LITERAL
--                              |     TK_WSTRING_LITERAL **
--(122)                         |     TK_CHAR_LITERAL
--                              |     TK_WCHAR_LITERAL **
--(123)                         |     TK_FIXED_LITERAL
--(124)                         |     TK_FLOAT_LITERAL
--(125)                         |     <boolean_literal>
--(126) <boolean_literal>       :=    TK_TRUE
--(127)                         |     TK_FALSE
--(136) <struct_type>           :=    TK_STRUCT TK_ID "{" <member_l> "}"
--(137) <member_l>              :=    <member> <member_r>
--(138) <member_r>              :=    <member> <member_r>
--(139)                         |     empty
--(140) <member>                :=    <type_spec> <declarator_l> ";"
--(141) <typedef_dcl_l>         :=    <typedef_dcl> <typedef_l_r>
--(142) <typedef_l_r>           :=    "," <typedef_dcl> <typedef_l_r>
--(143)                         |     empty
--(144) <typedef_dcl>           :=    TK_ID <fixed_array_size_l>
--(145) <fixed_array_size_l>    :=    <fixed_array_size> <fixed_array_size_l>
--(146)                         |     empty
--(147) <fixed_array_size>      :=    "[" <positive_int_const4> "]"
--(148) <union_type>            :=    TK_UNION TK_ID TK_SWITCH "(" <switch_type_spec> ")"
--                                    "{" <case_l> "}"
--(149) <switch_type_spec>      :=    <integer_type>
--(150)                         |     TK_LONG <long_e>
--(151)                         |     TK_CHAR
--(152)                         |     TK_BOOLEAN
--(153)                         |     TK_ENUM
--(154)                         |     <scoped_name>
--(155) <case_l>                :=    <case> <case_l_r>
--(156) <case_l_r>              :=    <case> <case_l_r>
--(157)                         |     empty
--(158) <case>                  :=    <case_label_l> <element_spec> ";"
--(159) <case_label_l>          :=    <case_label> <case_label_l_r>
--(160) <case_label_l_r>        :=    <case_label> <case_label_l_r>
--(161)                         |     empty
--(162) <case_label>            :=    TK_CASE <positive_int_const5> ":"
--(163)                         |     TK_DEFAULT ":"
--(164) <element_spec>          :=    <type_spec> <declarator>
--(165) <enum_type>             :=    TK_ENUM <enumerator>
--                                    "{" <enumerator> <enumerator_l> "}"
--(166) <enumerator_l>          :=    "," <enumerator> <enumerator_l>
--(167)                         |     empty
--(168) <union_or_struct>       :=    TK_STRUCT TK_ID <struct_tail>
--(169)                         |     TK_UNION TK_ID TK_SWITCH <union_tail>
--(170) <struct_tail>           :=    "{" <member_l> "}"
--(171)                         |     empty
--(172) <union_tail>            :=    TK_SWITCH "(" <switch_type_spec> ")"
--                                    "{" <case_l> "}"
--(173)                         |     empty
--(174) <const_dcl>             :=    TK_CONST <const_type> TK_ID "=" <positive_int_const>
--(175) <const_type>            :=    <float_type_or_int_type>
--(176)                         |     TK_CHAR
--                              |     TK_WCHAR **
--(177)                         |     TK_BOOLEAN
--(178)                         |     TK_STRING
--                              |     TK_WSTRING **
--(179)                         |     <scoped_name>
--(180)                         |     TK_OCTET
--(181)                         |     TK_FIXED
--(186) <except_dcl>            :=    TK_EXCEPTION TK_ID "{" <member_l_empty> "}"
--(187) <member_l_empty>        :=    <member> <member_l_empty>
--(188)                         |     empty
--(189) <inter_value_event>     :=    TK_ABSTRACT <abstract_tail>
--(190)                         |     TK_LOCAL TK_INTERFACE TK_ID <interface_tail>
--(191)                         |     TK_CUSTOM <value_or_event>
--(192)                         |     TK_INTERFACE TK_ID <interface_tail>
--(193)                         |     TK_VALUETYPE TK_ID <value_tail>
--(194)                         |     TK_EVENTTYPE TK_ID <eventtype_tail>
--(195) <abstract_tail>         :=    TK_INTERFACE TK_ID <interface_tail>
--(196)                         |     TK_VALUETYPE TK_ID <valueinhe_export_empty>
--(197)                         |     TK_EVENTTYPE TK_ID <valueinhe_export_empty>
--(198) <interface_tail>        :=    ":" <scoped_name> <inter_name_seq2> "{" <export_l> "}"
--(199)                         |     "{" <export_l> "}"
--(200)                         |     empty
--(205) <inter_name_seq2>       :=    "," <scoped_name> <inter_name_seq2>
--(206)                         |     empty
--(207) <export_l>              :=    <export> <export_l>
--(208)                         |     empty
--(209) <export>                :=    <type_dcl> ";"
--(210)                         |     <const_dcl> ";"
--(211)                         |     <except_dcl> ";"
--(212)                         |     <attr_dcl> ";"
--(213)                         |     <op_dcl> ";"
--(214)                         |     <type_id_dcl> ";"
--(215)                         |     <type_prefix_dcl> ";"
--(216) <attr_dcl>              :=    <readonly_attr_spec>
--(217)                         |     <attr_spec>
--(218) <readonly_attr_spec>    :=    TK_READONLY TK_ATTRIBUTE <param_type_spec> <readonly_attr_dec>
--(219) <param_type_spec>       :=    <base_type_spec>
--(220)                         |     <string_type>
--                              |     <wide_string_type> **
--(221)                         |     <scoped_name>
--(226) <readonly_attr_dec>     :=    TK_ID <readonly_attr_dec_tail>
--(227) <readonly_attr_dec_tail>:=    <raises_expr>
--(228)                         |     <simple_dec_l>
--                              |     empty
--(229) <raises_expr>           :=    TK_RAISES "(" <scoped_name> <inter_name_seq> ")"
--(230) <simple_dec_l)          :=    "," TK_ID <simple_dec_l>
--(231)                         |     empty
--(232) <attr_spec>             :=    TK_ATTRIBUTE <param_type_spec> <attr_declarator>
--(233) <attr_declarator>       :=    TK_ID <attr_declarator_tail>
--(234) <attr_declarator_tail>  :=    <attr_raises_expr>
--(235)                         |     <simple_dec_l>
--                              |     empty
--(236) <attr_raises_expr>      :=    TK_GETRAISES <exception_l> <attr_raises_expr_tail>
--(237)                         |     TK_SETRAISES <exception_l>
--(238) <attr_raises_expr_tail> :=    TK_SETRAISES <exception_l>
--(239)                         |     empty
--(240) <exception_l>           :=    "(" <scoped_name> <inter_name_seq> ")"
--(241) <inter_name_seq>        :=    "," <scoped_name> <inter_name_seq>
--(242)                         |     empty
--(243) <op_dcl>                :=    TK_ONEWAY <op_type_spec> TK_ID <parameter_dcls> <raises_expr_e>
--                                    <context_expr_e>
--(244)                         |     <op_type_spec> TK_ID <parameter_dcls> <raises_expr_e>
--                                    <context_expr_e>
--(245) <op_type_spec>          :=    <param_type_spec>
--(246)                         |     TK_VOID
--(247) <parameter_dcls>        :=    "(" <parameter_dcls_tail>
--(248) <parameter_dcls_tail>   :=    <param_dcl> <param_dcl_l>
--(249)                         |     ")"
--(250) <param_dcl>             :=    <param_attribute> <param_type_spec> TK_ID
--(251) <param_attribute>       :=    TK_IN
--(252)                         |     TK_OUT
--(253)                         |     TK_INOUT
--(254) <param_dcl_l>           :=    "," <param_dcl> <param_dcl_l>
--(255)                         |     empty
--(256) <context_expr>          :=    TK_CONTEXT "(" <context> <string_literal_l> ")"
--(257) <string_literal_l>      :=    "," <context> <string_literal_l>
--(258)                         |     empty
--(259) <type_id_dcl>           :=    TK_TYPEID <scoped_name> TK_STRING_LITERAL
--(260) <type_prefix_dcl>       :=    TK_TYPEPREFIX <scoped_name> TK_STRING_LITERAL
--(265) <valueinhe_export_empty>:=    <value_inhe_spec> "{" <export_l> "}
--(266)                         |     "{" <export_l> "}"
--(267)                         |     empty
--(268) <value_inhe_spec>       :=    ":" <truncatable_e> <value_name> <value_name_list>
--                                    <supports_e>
--(269)                         |     <supports_e>
--(270)                         |     empty
--(271) <truncatable_e>         :=    TK_TRUNCATABLE
--(272)                         |     empty
--(273) <value_name>            :=    TK_ID <value_name_l>
--(274)                         |     ":" ":" TK_ID <value_name_l>
--(275) <value_name_l>          :=    ":" ":" TK_ID <value_name_l>
--(276)                         |     empty
--(277) <value_name_list>       :=    "," <value_name> <value_name_list>
--(278)                         |     empty
--(279) <supports_e>            :=    TK_SUPPORTS <inter_name> <inter_name_seq2>
--(280)                         |     empty
--(281) <value_or_event>        :=    TK_VALUETYPE TK_ID <valueinhe_export>
--(282)                         |     TK_EVENTTYPE TK_ID <valueinhe_export>
--(283) <valueinhe_export>      :=    <value_inhe_spec> "{" <value_element_l> "}"
--(284)                         |     "{" <value_element_l> "}"
--(285) <value_element_l>       :=    <value_element> <value_element_l>
--(286)                         |     empty
--(287) <value_element>         :=    <export>
--(288)                         |     <state_member>
--(289)                         |     <init_dcl>
--(290) <state_member>          :=    TK_PUBLIC <type_spec> <declarator_l> ";"
--(291)                         |     TK_PRIVATE <type_spec> <declarator_l> ";"
--(292) <init_dcl>              :=    TK_FACTORY TK_ID "(" <init_param_dcl_l_e> ")"
--                                    <raises_expr_e> ";"
--(293) <init_param_dcl_l_e>    :=    <init_param_dcl> <init_param_dcl_l_e_r>
--(294)                         |     empty
--(295) <init_param_dcl_l_e_r>  :=    "," <init_param_dcl> <init_param_dcl_l_e_r>
--(296)                         |     empty
--(297) <init_param_dcl>        :=    TK_IN <param_type_spec> TK_ID
--(298) <value_tail>            :=    <value_inhe_spec> "{" <value_element_l> "}"
--(299)                         |     "{" <value_element_l> "}"
--(300)                         |     <type_spec>
--(301)                         |     empty
--(302) <eventtype_tail>        :=    <value_inhe_spec> "{" <value_element_l> "}"
--(303)                         |     "{" <value_element_l> "}"
--(304)                         |     empty
--(305) <module>                :=    TK_MODULE TK_ID "{" <definition_l> "}"
--(306) <component>             :=    TK_COMPONENT TK_ID <component_tail>
--(307) <component_tail>        :=    <component_inh_spec> <supp_inter_spec>
--                                    "{" <component_body> "}"
--(308)                         |     <supp_inter_spec> "{" <component_body> "}"
--(309)                         |     "{" <component_body> "}"
--(310)                         |     empty
--(311) <component_inh_spec>    :=    ":" <component_name>
--(312) <component_name>        :=    TK_ID <component_name_l>
--(313)                         |     ":" ":" TK_ID <component_name_l>
--(314) <component_name_l>      :=    ":" ":" TK_ID <component_name_l>
--(315)                         |     empty
--(316) <supp_inter_spec>       :=    TK_SUPPORTS <supp_name> <supp_name_list>
--(316e)                        |     empty
--(317) <supp_name>             :=    TK_ID <supp_name_l>
--(318)                         |     ":" ":" TK_ID <supp_name_l>
--(319) <supp_name_l>           :=    ":" ":" TK_ID <supp_name_l>
--(320)                         |     empty
--(321) <supp_name_list>        :=    "," <supp_name> <supp_name_list>
--(322)                         |     empty
--(323) <component_body>        :=    <component_export> <component_body>
--(324)                         |     empty
--(325) <component_export>      :=    <provides_dcl> ";"
--(326)                         |     <uses_dcl> ";"
--(327)                         |     <emits_dcl> ";"
--(328)                         |     <publishes_dcl> ";"
--(329)                         |     <consumes_dcl> ";"
--(330)                         |     <attr_dcl> ";"
--(331) <provides_dcl>          :=    TK_PROVIDES <interface_type> TK_ID
--(332) <interface_type>        :=    <scoped_name>
--(333)                         |     TK_OBJECT
--(338) <uses_dcl>              :=    TK_USES <multiple_e> <interface_type> TK_ID
--(339) <multiple_e>            :=    TK_MULTIPLE
--(340)                         |     empty
--(341) <emits_dcl>             :=    TK_EMITS <scoped_name> TK_ID
--(342) <publishes_dcl>         :=    TK_PUBLISHES <scoped_name> TK_ID
--(343) <consumes_dcl>          :=    TK_CONSUMES <scoped_name> TK_ID

--(344) <home_dcl>              :=    TK_HOME TK_ID <home_dcl_tail>
--(345) <home_dcl_tail>         :=    <home_inh_spec> <supp_inter_spec>
--                                    TK_MANAGES <home_name> <primary_key_spec_e>
--                                    "{" <home_export_l> "}"
--(346)                         |     <supp_inter_spec> TK_MANAGES <home_name> <primary_key_spec_e>
--                                    "{" <home_export_l> "}"
--(347)                         |     TK_MANAGES <home_name> <primary_key_spec_e>
--                                    "{" <home_export_l> "}"
--(348) <home_inh_spec>         :=    ":" <scoped_name>
--(353) <primary_key_spec_e>    :=    TK_PRIMARYKEY <scoped_name>
--(354)                         |     empty
--(359) <home_export_l>         :=    <home_export> <home_export_l>
--(360)                         |     empty
--(361) <home_export>           :=    <export>
--(362)                         |     <factory_dcl> ";"
--(363)                         |     <finder_dcl> ";"
--(364) <factory_dcl>           :=    TK_FACTORY TK_ID "(" <init_param_dcls> ")"
--                                    <raises_expr_e>
--(365) <finder_dcl>            :=    TK_FINDER TK_ID "(" <init_param_dcls> ")"
--                                    <raises_expr_e>
--(366) <init_param_dcls>       :=    <init_param_dcl> <init_param_dcl_list>
--(367)                         |     empty
--(368) <init_param_dcl_list>   :=    "," <init_param_dcl> <init_param_dcl_list>
--(369)                         |     empty
--(370) <raises_expr_e>         :=    <raises_expr>
--(371)                         |     empty
--(376) <enumerator>            :=    TK_ID
--(377) <context_expr_e>        :=    <context_expr>
--(378)                         |     empty
--(379) <context>               :=    TK_STRING_LITERAL 

--debug
local print = print

local type     = type
local pairs    = pairs
local tonumber = tonumber
local require  = require
local error    = error
local ipairs   = ipairs

local math     = require "math"
local string   = require "string"
local table    = require "table"

module( 'luaidl.sin' )

local lex = require 'luaidl.lex'

local tab_firsts = { }
local tab_follow = { }

local function set_firsts( tab_firstsparm )
  local tab_tmp = { }
  for _, v in ipairs( tab_firstsparm ) do
    local id = lex.tab_tokens[ v ]
    if ( id ) then
      tab_tmp[ id ] = true
    else
      tab_tmp[ v ] = true
    end -- if
  end -- for 
  return tab_tmp
end

tab_firsts.rule_1   = set_firsts { 'TK_IMPORT' }
tab_firsts.rule_11  = set_firsts { 'TK_TYPEDEF','TK_ENUM','TK_NATIVE','TK_UNION','TK_STRUCT',
                        'TK_CONST','TK_EXCEPTION','TK_ABSTRACT','TK_LOCAL',
                        'TK_INTERFACE','TK_CUSTOM','TK_VALUETYPE',
                        'TK_EVENTTYPE','TK_MODULE','TK_TYPEID',
                        'TK_TYPEPREFIX','TK_COMPONENT','TK_HOME'
                      }
tab_firsts.rule_12  = tab_firsts.rule_11
tab_firsts.rule_14  = set_firsts { 'TK_TYPEDEF', 'TK_ENUM', 'TK_NATIVE', 'TK_UNION', 'TK_STRUCT' }
tab_firsts.rule_15  = set_firsts { 'TK_CONST' }
tab_firsts.rule_16  = set_firsts { 'TK_EXCEPTION' }
tab_firsts.rule_17  = set_firsts { 'TK_ABSTRACT', 'TK_LOCAL', 'TK_INTERFACE', 'TK_CUSTOM',
                        'TK_VALUETYPE', 'TK_EVENTTYPE'
                       }
tab_firsts.rule_18  = set_firsts { 'TK_MODULE' }
tab_firsts.rule_19  = set_firsts { 'TK_TYPEID' }
tab_firsts.rule_20  = set_firsts { 'TK_TYPEPREFIX' }
tab_firsts.rule_21  = set_firsts { 'TK_COMPONENT' }
tab_firsts.rule_22  = set_firsts { 'TK_HOME' }
tab_firsts.rule_23  = set_firsts { 'TK_TYPEDEF' }
tab_firsts.rule_24  = set_firsts { 'TK_ENUM' }
tab_firsts.rule_25  = set_firsts { 'TK_NATIVE' }
tab_firsts.rule_26  = set_firsts { 'TK_STRUCT', 'TK_UNION' }
tab_firsts.rule_27  = set_firsts { 'TK_CHAR', 'TK_BOOLEAN', 'TK_OCTET', 'TK_ANY', 'TK_OBJECT',
                        'TK_VALUEBASE', 'TK_LONG', 'TK_FLOAT', 'TK_DOUBLE', 'TK_SHORT',
                        'TK_UNSIGNED', 'TK_SEQUENCE' , 'TK_STRING', 'TK_FIXED' , 
                        'TK_ID', ":", 'TK_STRUCT', 'TK_UNION', 'TK_ENUM', 'TK_TYPECODE',
                      }
tab_firsts.rule_28  = set_firsts { 'TK_CHAR', 'TK_BOOLEAN', 'TK_OCTET', 'TK_ANY', 'TK_OBJECT',
                        'TK_VALUEBASE', 'TK_LONG', 'TK_FLOAT', 'TK_DOUBLE', 'TK_SHORT',
                        'TK_UNSIGNED', 'TK_SEQUENCE' , 'TK_STRING', 'TK_FIXED' , 
                        'TK_ID', ":", 'TK_TYPECODE',
                       }
tab_firsts.rule_29  = set_firsts { 'TK_STRUCT', 'TK_UNION', 'TK_ENUM' }
tab_firsts.rule_30  = set_firsts { 'TK_CHAR', 'TK_BOOLEAN', 'TK_OCTET', 'TK_ANY', 'TK_OBJECT',
                        'TK_VALUEBASE', 'TK_LONG', 'TK_FLOAT', 'TK_DOUBLE', 'TK_SHORT',
                        'TK_UNSIGNED', 'TK_TYPECODE',
                       }
tab_firsts.rule_31  = set_firsts { 'TK_SEQUENCE', 'TK_STRING', 'TK_FIXED' }
tab_firsts.rule_32  = set_firsts { 'TK_ID', ':' }

tab_firsts.rule_33  = set_firsts { 'TK_STRUCT' }
tab_firsts.rule_34  = set_firsts { 'TK_UNION' }
tab_firsts.rule_35  = set_firsts { 'TK_ENUM' }
tab_firsts.rule_36  = set_firsts { 'TK_FLOAT', 'TK_DOUBLE', 'TK_SHORT', 'TK_UNSIGNED', 'TK_LONG' }
tab_firsts.rule_37  = set_firsts { 'TK_CHAR' }
tab_firsts.rule_38  = set_firsts { 'TK_BOOLEAN' }
tab_firsts.rule_39  = set_firsts { 'TK_OCTET' }
tab_firsts.rule_40  = set_firsts { 'TK_ANY' }
tab_firsts.rule_41  = set_firsts { 'TK_OBJECT' }
tab_firsts.rule_42  = set_firsts { 'TK_VALUEBASE' }

tab_firsts.rule_43  = set_firsts { 'TK_FLOAT', 'TK_DOUBLE' }
tab_firsts.rule_44  = set_firsts { 'TK_SHORT', 'TK_UNSIGNED' }
tab_firsts.rule_45  = set_firsts { 'TK_LONG' }
tab_firsts.rule_46  = set_firsts { 'TK_FLOAT' }
tab_firsts.rule_47  = set_firsts { 'TK_DOUBLE' }
tab_firsts.rule_48  = set_firsts { 'TK_SHORT' }
tab_firsts.rule_49  = set_firsts { 'TK_UNSIGNED' }
tab_firsts.rule_50  = tab_firsts.rule_49
tab_firsts.rule_51  = tab_firsts.rule_45
tab_firsts.rule_52  = set_firsts { 'TK_SHORT' }
tab_firsts.rule_53  = set_firsts { 'TK_LONG' }
tab_firsts.rule_55  = set_firsts { 'TK_LONG' }
tab_firsts.rule_56  = set_firsts { 'TK_DOUBLE' }

tab_firsts.rule_58  = set_firsts { 'TK_SEQUENCE' }
tab_firsts.rule_59  = set_firsts { 'TK_STRING' }
tab_firsts.rule_60  = set_firsts { 'TK_FIXED' }

tab_firsts.rule_62  = tab_firsts.rule_30
tab_firsts.rule_63  = tab_firsts.rule_31
tab_firsts.rule_64  = tab_firsts.rule_32

tab_firsts.rule_69  = set_firsts { ',' }
tab_firsts.rule_70  = set_firsts { '>' }
tab_firsts.rule_72  = set_firsts { '<' }
tab_firsts.rule_75  = set_firsts { '-', '+', '~', '(', 'TK_ID', ':', 'TK_INTEGER_LITERAL',
                                   'TK_STRING_LITERAL', 'TK_CHAR_LITERAL', 'TK_FIXED_LITERAL',
                                   'TK_FLOAT_LITERAL', 'TK_TRUE', 'TK_FALSE'
                      }
tab_firsts.rule_93   = tab_firsts.rule_75
tab_firsts.rule_91   = set_firsts { '|' }
tab_firsts.rule_94   = set_firsts { '^' }
tab_firsts.rule_96   = tab_firsts.rule_75
tab_firsts.rule_97   = set_firsts { '&' }
tab_firsts.rule_99   = tab_firsts.rule_75
tab_firsts.rule_100  = set_firsts { '>>' }
tab_firsts.rule_101  = set_firsts { '<<' }
tab_firsts.rule_103  = tab_firsts.rule_75
tab_firsts.rule_104  = set_firsts { '+' }
tab_firsts.rule_105  = set_firsts { '-' }
tab_firsts.rule_107  = tab_firsts.rule_75
tab_firsts.rule_108  = set_firsts { '*' }
tab_firsts.rule_109  = set_firsts { '/' }
tab_firsts.rule_110  = set_firsts { '%' }
tab_firsts.rule_112  = set_firsts { '-', '+', '~' }
tab_firsts.rule_113  = set_firsts { '(', 'TK_ID', ':', 'TK_INTEGER_LITERAL',
                                    'TK_STRING_LITERAL', 'TK_CHAR_LITERAL', 'TK_FIXED_LITERAL',
                                    'TK_FLOAT_LITERAL', 'TK_TRUE', 'TK_FALSE'
                       }
tab_firsts.rule_114  = set_firsts { '-' }
tab_firsts.rule_115  = set_firsts { '+' }
tab_firsts.rule_116  = set_firsts { '~' }
tab_firsts.rule_117  = set_firsts { 'TK_ID', ':' }
tab_firsts.rule_118  = set_firsts { 'TK_INTEGER_LITERAL', 'TK_STRING_LITERAL', 'TK_CHAR_LITERAL',
                                    'TK_FIXED_LITERAL', 'TK_FLOAT_LITERAL', 'TK_TRUE', 'TK_FALSE'
                       }
tab_firsts.rule_119  = set_firsts { '(' }
tab_firsts.rule_120  = set_firsts { 'TK_INTEGER_LITERAL' }
tab_firsts.rule_121  = set_firsts { 'TK_STRING_LITERAL' }
tab_firsts.rule_122  = set_firsts { 'TK_CHAR_LITERAL' }
tab_firsts.rule_123  = set_firsts { 'TK_FIXED_LITERAL' }
tab_firsts.rule_124  = set_firsts { 'TK_FLOAT_LITERAL' }
tab_firsts.rule_125  = set_firsts { 'TK_TRUE', 'TK_FALSE' }
tab_firsts.rule_126  = set_firsts { 'TK_TRUE' }
tab_firsts.rule_127  = set_firsts { 'TK_FALSE' }

tab_firsts.rule_137  = tab_firsts.rule_27
tab_firsts.rule_138  = tab_firsts.rule_137

tab_firsts.rule_140  = tab_firsts.rule_138
tab_firsts.rule_141  = set_firsts { 'TK_ID' }
tab_firsts.rule_142  = set_firsts { "," }

tab_firsts.rule_144  = tab_firsts.rule_141
tab_firsts.rule_145  = set_firsts { "[" }

tab_firsts.rule_147  = tab_firsts.rule_145
tab_firsts.rule_148  = set_firsts { 'TK_UNION' }
tab_firsts.rule_149  = tab_firsts.rule_44
tab_firsts.rule_150  = set_firsts { 'TK_LONG' }
tab_firsts.rule_151  = set_firsts { 'TK_CHAR' }
tab_firsts.rule_152  = set_firsts { 'TK_BOOLEAN' }
tab_firsts.rule_153  = set_firsts { 'TK_ENUM' }
tab_firsts.rule_154  = set_firsts { 'TK_ID', '::' }
tab_firsts.rule_155  = set_firsts { 'TK_CASE', 'TK_DEFAULT' }
tab_firsts.rule_156  = set_firsts { 'TK_CASE', 'TK_DEFAULT' }

tab_firsts.rule_158  = set_firsts { 'TK_CASE', 'TK_DEFAULT' }
tab_firsts.rule_159  = set_firsts { 'TK_CASE', 'TK_DEFAULT' }
tab_firsts.rule_160  = set_firsts { 'TK_CASE', 'TK_DEFAULT' }

tab_firsts.rule_162  = set_firsts { 'TK_CASE' }
tab_firsts.rule_163  = set_firsts { 'TK_DEFAULT' }
tab_firsts.rule_164  = tab_firsts.rule_27

tab_firsts.rule_166  = set_firsts { "," }

tab_firsts.rule_168  = set_firsts { 'TK_STRUCT' }
tab_firsts.rule_169  = set_firsts { 'TK_UNION' }
tab_firsts.rule_170  = set_firsts { '{' }

tab_firsts.rule_172  = set_firsts { 'TK_SWITCH' }

tab_firsts.rule_174  = set_firsts { 'TK_CONST' }
tab_firsts.rule_175  = tab_firsts.rule_36
tab_firsts.rule_176  = set_firsts { 'TK_CHAR' }
tab_firsts.rule_177  = set_firsts { 'TK_BOOLEAN' }
tab_firsts.rule_178  = set_firsts { 'TK_STRING' }
tab_firsts.rule_179  = set_firsts { 'TK_ID', ':' }
tab_firsts.rule_180  = set_firsts { 'TK_OCTET' }
tab_firsts.rule_181  = set_firsts { 'TK_FIXED' }
tab_firsts.rule_186  = set_firsts { 'TK_EXCEPTION' }
tab_firsts.rule_187  = tab_firsts.rule_137

tab_firsts.rule_189  = set_firsts { 'TK_ABSTRACT' }
tab_firsts.rule_190  = set_firsts { 'TK_LOCAL' }
tab_firsts.rule_191  = set_firsts { 'TK_CUSTOM' }
tab_firsts.rule_192  = set_firsts { 'TK_INTERFACE' }
tab_firsts.rule_193  = set_firsts { 'TK_VALUETYPE' }
tab_firsts.rule_194  = set_firsts { 'TK_EVENTTYPE' }
tab_firsts.rule_195  = set_firsts { 'TK_INTERFACE' }
tab_firsts.rule_196  = set_firsts { 'TK_VALUETYPE' }
tab_firsts.rule_198  = set_firsts { ':' }
tab_firsts.rule_199  = set_firsts { '{' }

tab_firsts.rule_207  = set_firsts { 'TK_ONEWAY', 'TK_VOID', 'TK_STRING', 'TK_ID', ':',
                        'TK_CHAR', 'TK_BOOLEAN', 'TK_OCTET', 'TK_ANY',
                        'TK_OBJECT', 'TK_VALUEBASE', 'TK_LONG', 'TK_FLOAT',
                        'TK_DOUBLE', 'TK_SHORT', 'TK_UNSIGNED','TK_TYPEDEF',
                        'TK_ENUM', 'TK_NATIVE', 'TK_UNION', 'TK_STRUCT',
                        'TK_EXCEPTION', 'TK_READONLY', 'TK_ATTRIBUTE', 'TK_TYPECODE',
                       }

tab_firsts.rule_209  = tab_firsts.rule_14
tab_firsts.rule_211  = set_firsts { 'TK_EXCEPTION' }
tab_firsts.rule_212  = set_firsts { 'TK_READONLY', 'TK_ATTRIBUTE' }
tab_firsts.rule_213  = set_firsts { 'TK_ONEWAY', 'TK_VOID', 'TK_STRING', 'TK_ID', ':',
                        'TK_CHAR', 'TK_BOOLEAN', 'TK_OCTET', 'TK_ANY',
                        'TK_OBJECT', 'TK_VALUEBASE', 'TK_LONG', 'TK_FLOAT',
                        'TK_DOUBLE', 'TK_SHORT', 'TK_UNSIGNED', 'TK_TYPECODE',
                       }

tab_firsts.rule_216  = set_firsts { 'TK_READONLY' }
tab_firsts.rule_217  = set_firsts { 'TK_ATTRIBUTE' }

tab_firsts.rule_219  = tab_firsts.rule_30
tab_firsts.rule_220  = set_firsts { 'TK_STRING' }
tab_firsts.rule_221  = tab_firsts.rule_32


tab_firsts.rule_227  = set_firsts { 'TK_RAISES' }
tab_firsts.rule_228  = set_firsts { ',' }

tab_firsts.rule_230  = set_firsts { 'TK_ID' }
tab_firsts.rule_234  = set_firsts { 'TK_GETRAISES', 'TK_SETRAISES' }
tab_firsts.rule_235  = set_firsts { ',' }
tab_firsts.rule_236  = set_firsts { 'TK_GETRAISES' }
tab_firsts.rule_237  = set_firsts { 'TK_SETRAISES' }
tab_firsts.rule_238  = tab_firsts.rule_237
                       
tab_firsts.rule_243  = set_firsts { 'TK_ONEWAY' }
tab_firsts.rule_244  = set_firsts { 'TK_VOID', 'TK_STRING', 'TK_ID', ':',
                        'TK_CHAR', 'TK_BOOLEAN', 'TK_OCTET', 'TK_ANY',
                        'TK_OBJECT', 'TK_VALUEBASE', 'TK_LONG', 'TK_FLOAT',
                        'TK_DOUBLE', 'TK_SHORT', 'TK_UNSIGNED', 'TK_TYPECODE',
                       }
tab_firsts.rule_245  = set_firsts { 'TK_CHAR', 'TK_BOOLEAN', 'TK_OCTET', 'TK_ANY', 'TK_OBJECT',
                        'TK_VALUEBASE', 'TK_LONG', 'TK_FLOAT', 'TK_DOUBLE', 'TK_SHORT',
                        'TK_UNSIGNED', 'TK_STRING', 'TK_ID', ":", 'TK_TYPECODE',
                       }
tab_firsts.rule_246  = set_firsts { 'TK_VOID' }

tab_firsts.rule_248  = set_firsts { 'TK_IN', 'TK_OUT', 'TK_INOUT' }
tab_firsts.rule_249  = set_firsts { ')' } 

tab_firsts.rule_251  = set_firsts { 'TK_IN' }
tab_firsts.rule_252  = set_firsts { 'TK_OUT' }
tab_firsts.rule_253  = set_firsts { 'TK_INOUT' }
tab_firsts.rule_254  = set_firsts { ',' }

tab_firsts.rule_257  = set_firsts { ',' }

tab_firsts.rule_268  = set_firsts { ':' }
tab_firsts.rule_269  = set_firsts { 'TK_SUPPORTS' }
tab_firsts.rule_271  = set_firsts { 'TK_TRUNCATABLE' }
tab_firsts.rule_277  = set_firsts { ',' }
tab_firsts.rule_281  = set_firsts { 'TK_VALUETYPE' }
tab_firsts.rule_285  = set_firsts { 'TK_ONEWAY', 'TK_VOID', 'TK_STRING', 'TK_ID', ':',
                        'TK_CHAR', 'TK_BOOLEAN', 'TK_OCTET', 'TK_ANY',
                        'TK_OBJECT', 'TK_VALUEBASE', 'TK_LONG', 'TK_FLOAT',
                        'TK_DOUBLE', 'TK_SHORT', 'TK_UNSIGNED','TK_TYPEDEF',
                        'TK_ENUM', 'TK_NATIVE', 'TK_UNION', 'TK_STRUCT',
                        'TK_EXCEPTION', 'TK_READONLY', 'TK_ATTRIBUTE', 'TK_TYPECODE',
                        'TK_PUBLIC', 'TK_PRIVATE',
                        'TK_FACTORY' }
tab_firsts.rule_287  = tab_firsts.rule_207
tab_firsts.rule_288  = set_firsts { 'TK_PUBLIC', 'TK_PRIVATE' }
tab_firsts.rule_289  = set_firsts { 'TK_FACTORY' }
tab_firsts.rule_290  = set_firsts { 'TK_PUBLIC' }
tab_firsts.rule_291  = set_firsts { 'TK_PRIVATE' }
tab_firsts.rule_292  = tab_firsts.rule_289
tab_firsts.rule_297  = set_firsts { 'TK_IN' }
tab_firsts.rule_298  = set_firsts { ':', 'TK_SUPPORTS' }
tab_firsts.rule_299  = set_firsts { '{' }
tab_firsts.rule_300  = tab_firsts.rule_27
tab_firsts.rule_302  = tab_firsts.rule_298
tab_firsts.rule_303  = set_firsts { '{' }
tab_firsts.rule_305  = set_firsts { 'TK_MODULE' }
tab_firsts.rule_306  = set_firsts { 'TK_COMPONENT' }
tab_firsts.rule_307  = set_firsts { ':' }
tab_firsts.rule_308  = set_firsts { 'TK_SUPPORTS' }
tab_firsts.rule_309  = set_firsts { '{' }
tab_firsts.rule_316  = set_firsts { 'TK_SUPPORTS' }
tab_firsts.rule_321  = set_firsts { ',' }
tab_firsts.rule_323  = set_firsts { 'TK_PROVIDES', 'TK_USES', 'TK_EMITS', 'TK_PUBLISHES', 
                                    'TK_CONSUMES', 'TK_READONLY', 'TK_ATTRIBUTE' }
tab_firsts.rule_325  = set_firsts { 'TK_PROVIDES' }
tab_firsts.rule_326  = set_firsts { 'TK_USES' }
tab_firsts.rule_327  = set_firsts { 'TK_EMITS' }
tab_firsts.rule_328  = set_firsts { 'TK_PUBLISHES' }
tab_firsts.rule_329  = set_firsts { 'TK_CONSUMES' }
tab_firsts.rule_330  = set_firsts { 'TK_READONLY', 'TK_ATTRIBUTE' }
tab_firsts.rule_332  = set_firsts { 'TK_ID', ':' }
tab_firsts.rule_333  = set_firsts { 'TK_OBJECT' }
tab_firsts.rule_339  = set_firsts { 'TK_MULTIPLE' }
tab_firsts.rule_345  = set_firsts { ':' }
tab_firsts.rule_346  = set_firsts { 'TK_SUPPORTS' }
tab_firsts.rule_347  = set_firsts { 'TK_MANAGES' }
tab_firsts.rule_353  = set_firsts { 'TK_PRIMARYKEY' }
tab_firsts.rule_359  = set_firsts { 'TK_ONEWAY', 'TK_VOID', 'TK_STRING', 'TK_ID', ':',
                        'TK_CHAR', 'TK_BOOLEAN', 'TK_OCTET', 'TK_ANY',
                        'TK_OBJECT', 'TK_VALUEBASE', 'TK_LONG', 'TK_FLOAT',
                        'TK_DOUBLE', 'TK_SHORT', 'TK_UNSIGNED','TK_TYPEDEF',
                        'TK_ENUM', 'TK_NATIVE', 'TK_UNION', 'TK_STRUCT',
                        'TK_EXCEPTION', 'TK_READONLY', 'TK_ATTRIBUTE', 'TK_TYPECODE',
                        'TK_FACTORY', 'TK_FINDER'
                       }
tab_firsts.rule_361  = tab_firsts.rule_207
tab_firsts.rule_362  = set_firsts { 'TK_FACTORY' }
tab_firsts.rule_363  = set_firsts { 'TK_FINDER' }
tab_firsts.rule_364  = tab_firsts.rule_362
tab_firsts.rule_365  = tab_firsts.rule_363
tab_firsts.rule_366  = tab_firsts.rule_297
tab_firsts.rule_368  = set_firsts { ',' }
tab_firsts.rule_370  = set_firsts { 'TK_RAISES' }

tab_firsts.rule_377  = set_firsts { 'TK_CONTEXT' }

tab_follow.rule_32   = set_firsts { 'TK_ID' }
tab_follow.rule_54   = set_firsts { 'TK_ID' }
tab_follow.rule_61   = set_firsts { '>', ',' }
tab_follow.rule_64   = set_firsts { ',', '>' }
tab_follow.rule_69   = set_firsts { '>' }
tab_follow.rule_72   = set_firsts { '>' }
tab_follow.rule_73   = set_firsts { 'TK_ID' }
tab_follow.rule_95   = set_firsts { '|', ']', ')' }
tab_follow.rule_98   = set_firsts { '^', ']', ')' }
tab_follow.rule_102  = set_firsts { '&', ']', ')' }
tab_follow.rule_106  = set_firsts { '>>', '<<', '&', '^', '|', ']', ')' }
tab_follow.rule_111  = set_firsts { '+', '-', '>>', '<<', '&', '^', '|', ']', ')' }
tab_follow.rule_119  = set_firsts { ')' }
tab_follow.rule_139  = set_firsts { '}' }
tab_follow.rule_143  = set_firsts { ';' }
tab_follow.rule_146  = set_firsts { ',', ';' }
tab_follow.rule_147  = set_firsts { '*', '/', '%', '+', '-', '>>', '<<', '&', '^', '|', ']', ')' }
tab_follow.rule_148  = set_firsts { ')' }
tab_follow.rule_154  = set_firsts { ',', ')' }
tab_follow.rule_157  = set_firsts { '}' }
tab_follow.rule_161  = set_firsts { 'TK_CHAR', 'TK_BOOLEAN', 'TK_OCTET', 'TK_ANY', 'TK_OBJECT',
                        'TK_VALUEBASE', 'TK_LONG', 'TK_FLOAT', 'TK_DOUBLE', 'TK_SHORT',
                        'TK_UNSIGNED', 'TK_SEQUENCE' , 'TK_STRING', 'TK_FIXED' , 
                        'TK_ID', ":", 'TK_STRUCT', 'TK_UNION', 'TK_ENUM', 'TK_TYPECODE',
                       }
tab_follow.rule_162  = set_firsts { ":" }
tab_follow.rule_167  = set_firsts { "}" }
tab_follow.rule_204  = set_firsts { ',', '{' }
tab_follow.rule_221  = set_firsts { 'TK_ID' }
tab_follow.rule_229  = set_firsts { ',', ')' }
tab_follow.rule_268  = set_firsts { ',', 'TK_SUPPORTS', '{' }
tab_follow.rule_272  = set_firsts { ':', 'TK_ID' }
tab_follow.rule_278  = set_firsts { 'TK_SUPPORTS', '{' }
tab_follow.rule_286  = set_firsts { '}' }
tab_follow.rule_301  = set_firsts { ';' }
tab_follow.rule_304  = set_firsts { ';' }
tab_follow.rule_307  = set_firsts { 'TK_SUPPORTS', '{' }
tab_follow.rule_308  = set_firsts { ',', '{' }
tab_follow.rule_316  = set_firsts { ',', '{' }
tab_follow.rule_316e = set_firsts { '{' }
tab_follow.rule_321  = tab_follow.rule_316
tab_follow.rule_332  = set_firsts { 'TK_ID' }
tab_follow.rule_340  = set_firsts { 'TK_MULTIPLE', 'TK_ID', ':', 'TK_OBJECT' }
tab_follow.rule_341  = set_firsts { 'TK_ID' }
tab_follow.rule_342  = tab_follow.rule_341
tab_follow.rule_343  = tab_follow.rule_342
tab_follow.rule_345  = set_firsts { ',', ':', 'TK_MANAGES' }
tab_follow.rule_347  = set_firsts { 'TK_PRIMARYKEY', '{' }
tab_follow.rule_348  = set_firsts { 'TK_SUPPORTS' }
tab_follow.rule_353  = set_firsts { '{' }
tab_follow.rule_359  = set_firsts { '}' }
tab_follow.rule_367  = set_firsts { ',', ')' }
tab_follow.rule_369  = set_firsts { ')' }
tab_follow.rule_600  = set_firsts { 'TK_STRING_LITERAL' }
tab_follow_rule_error_msg = { [32]  = 'identifier',
                              [64]  = "',' or '>'",
                              [154] = "',' or ')'",
                              [161] = "'char', 'boolean', 'octet', 'any', 'Object',"..
                                      "'ValueBase', 'long', 'float', 'double', 'short'"..
                                      "'unsigned', 'sequence', 'string', 'fixed', identifier,"..
                                      "'struct', 'union', 'enum'",
                              [204] = "',', '{'",
                              [221] = "identifier",
                              [229] = "',', ')'",
                              [268] = "',', 'supports' or '{'",
                              [307] = "'{'",
                              [308] = "',' or '{'",
                              [345] = "':', ',' or 'manages'",
                              [316] = "',', '{'",
                              [332] = "identifier",
                              [600] = 'string literal', 
                            }

local token = lex.token

local tab_curr_scope
local tab_global_scope
local tab_namespaces
local tab_prefix_pragma_stack
local oldPrefix

local label

-- this a list of type declarations
local TAB_TYPEID = {
               [ 'CONST' ]     = 'const', 
               [ 'NATIVE' ]    = 'native',
               [ 'CHAR' ]      = 'char',
               [ 'BOOLEAN' ]   = 'boolean',
               [ 'OCTET' ]     = 'octet',
               [ 'ANY' ]       = 'any',
               [ 'OBJECT' ]    = 'Object',
               [ 'VALUEBASE' ] = 'valuebase',
               [ 'STRUCT' ]    = 'struct',
               [ 'FLOAT' ]     = 'float',
               [ 'SHORT' ]     = 'short',
               [ 'FLOAT' ]     = 'float', 
               [ 'DOUBLE' ]    = 'double',
               [ 'USHORT' ]    = 'ushort',
               [ 'ULLONG' ]    = 'ullong',
               [ 'ULONG' ]     = 'ulong',
               [ 'LLONG' ]     = 'llong',
               [ 'LDOUBLE' ]   = 'ldouble',
               [ 'LONG' ]      = 'long',
               [ 'STRING']     = 'string',
               [ 'FIXED' ]     = 'fixed',
               [ 'EXCEPTION' ] = 'except',
               [ 'INTERFACE' ] = 'interface',
               [ 'VOID' ]      = 'void',
               [ 'OPERATION' ] = 'operation',
               [ 'TYPEDEF' ]   = 'typedef',
               [ 'ENUM' ]      = 'enum',
               [ 'SEQUENCE' ]  = 'sequence',
               [ 'ATTRIBUTE' ] = 'attribute',
               [ 'MODULE' ]    = 'module',
               [ 'UNION' ]     = 'union',
               [ 'TYPECODE' ]  = 'TypeCode',
               [ 'COMPONENT' ] = 'component',
               [ 'HOME' ]      = 'home',
               [ 'FACTORY' ]   = 'factory',
               [ 'FINDER' ]    = 'finder',
               [ 'VALUETYPE' ] = 'valuetype',
               [ 'EVENTTYPE' ] = 'eventtype',
             }

local TAB_BASICTYPE = { 
               [ 'NATIVE' ]    = { _type = TAB_TYPEID[ 'NATIVE' ] },
               [ 'CHAR' ]      = { _type = TAB_TYPEID[ 'CHAR' ] },
               [ 'BOOLEAN' ]   = { _type = TAB_TYPEID[ 'BOOLEAN' ] },
               [ 'OCTET' ]     = { _type = TAB_TYPEID[ 'OCTET' ] },
               [ 'ANY' ]       = { _type = TAB_TYPEID[ 'ANY' ] },
               [ 'OBJECT' ]    = { _type = TAB_TYPEID[ 'OBJECT' ],
                                   repID = 'IDL:omg.org/CORBA/Object:1.0' },
               [ 'VALUEBASE' ] = { _type = TAB_TYPEID[ 'VALUEBASE' ] },
               [ 'FLOAT' ]     = { _type = TAB_TYPEID[ 'FLOAT' ] },
               [ 'SHORT' ]     = { _type = TAB_TYPEID[ 'SHORT' ] },
               [ 'FLOAT' ]     = { _type = TAB_TYPEID[ 'FLOAT' ] } , 
               [ 'DOUBLE' ]    = { _type = TAB_TYPEID[ 'DOUBLE' ] },
               [ 'USHORT' ]    = { _type = TAB_TYPEID[ 'USHORT' ] },
               [ 'ULLONG' ]    = { _type = TAB_TYPEID[ 'ULLONG' ] },
               [ 'ULONG' ]     = { _type = TAB_TYPEID[ 'ULONG' ] },
               [ 'LLONG' ]     = { _type = TAB_TYPEID[ 'LLONG' ] },
               [ 'LDOUBLE' ]   = { _type = TAB_TYPEID[ 'LDOUBLE' ] },
               [ 'LONG' ]      = { _type = TAB_TYPEID[ 'LONG' ] },
               [ 'FIXED' ]     = { _type = TAB_TYPEID[ 'FIXED' ] },
               [ 'VOID' ]      = { _type = TAB_TYPEID[ 'VOID' ] },
               [ 'TYPECODE' ]  = { _type = TAB_TYPEID[ 'TYPECODE' ] },
	        }

local ERRMSG_DECLARED       = "'%s' has already been declared"
local ERRMSG_PARAMDECLARED  = "parameter '%s' has already been declared"
local ERRMSG_RAISESDECLARED = "raise '%s' has already been declared"
local ERRMSG_OPDECLARED     = "operation '%s' has already been declared"
local ERRMSG_REDEFINITION   = "redefinition of '%s'"
local ERRMSG_NOTTYPE        = "%s is not a legal type"
local ERRMSG_UNDECLARED     = "%s is an undeclared type"
local ERRMSG_FORWARD        = "There is a forward reference to %s, but it is not defined"

local function sin_error( val_expected )
  error( string.format( "%s(line %i): %s expected, encountered '%s'." , 
         lex.srcfilename, lex.line , val_expected , lex.tokenvalue ) , 2 
  )
end

local function sem_error( error_msg )
  local scope_name = tab_curr_scope.absolute_name 
  if scope_name == '' then
    scope_name = 'GLOBAL'
  end --if
  error( string.format( "%s(line %i):Scope:'%s': %s.", lex.srcfilename, 
         lex.line, scope_name, error_msg ), 2 )
end

local function isForward()
  for k, _ in pairs( tab_forward ) do
    sem_error( string.format( ERRMSG_FORWARD, k ) )
  end --for
end

local function goto_father_scope()
  if tab_namespaces[ tab_curr_scope.absolute_name ].prefix then
    tab_namespaces[ tab_curr_scope.absolute_name ].prefix = false
    table.remove( tab_prefix_pragma_stack )
  end --if 
  tab_curr_scope = tab_namespaces[ tab_curr_scope.absolute_name ].father_scope
end

local function dclName( name, tab_scope, tab_namespace, error_msg )
  if tab_namespaces[ name ] then
    if not error_msg then
      error_msg = ERRMSG_DECLARED
    end --if
    sem_error( string.format( error_msg, name ) )
  else
    local scope = tab_scope.absolute_name
    if ( not tab_namespace ) then
      tab_namespaces[ scope..'::'..name ] = true
    else
      tab_namespaces[ scope..'::'..name ] = { }
      tab_namespaces[ scope..'::'..name ].tab_namespace = tab_namespace
    end --if
  end --if
end

------
local function new_name( key, name, tab, value, error_msg, keyv )
  key = tab_curr_scope.absolute_name..'.'..key
  if ( tab_namespaces[ key ] ) then
    sem_error( string.format( error_msg, name ) )
  else
    tab_namespaces[ key ] = { }
    if keyv then
      tab[ keyv ] = value
    else
      table.insert( tab, value )
    end --if
  end --if
end
------
local function new_attr( key, value )
  tab_namespaces[ tab_curr_scope.absolute_name ].tab_namespace[ key ] = value
end

local function get_scope( part )
  local t = tab_namespaces[ tab_curr_scope.absolute_name ]
  local s
  if t then
    s = t[ part ]
  else
    s = ''
  end --if
  return s
end

local function get_absolutename( tab_scope, name )
  return tab_scope.absolute_name..'::'..name
end

local function is_legal_type( type )
  local tab_legal_type = { 
    [ TAB_TYPEID.TYPEDEF ] = true,
    [ TAB_TYPEID.STRUCT ] = true,
    [ TAB_TYPEID.ENUM ] = true,
    [ TAB_TYPEID.INTERFACE ] = true,
    [ TAB_TYPEID.NATIVE ] = true,
    [ TAB_TYPEID.UNION ] = true,
    [ TAB_TYPEID.CHAR ] = true,
    [ TAB_TYPEID.BOOLEAN ] = true,
    [ TAB_TYPEID.OCTET ] = true,
    [ TAB_TYPEID.ANY ] = true,
    [ TAB_TYPEID.OBJECT ] = true,
    [ TAB_TYPEID.VALUEBASE ] = true,
    [ TAB_TYPEID.FLOAT ] = true,
    [ TAB_TYPEID.DOUBLE ] = true,
    [ TAB_TYPEID.SHORT ] = true,
    [ TAB_TYPEID.USHORT ] = true,
    [ TAB_TYPEID.ULLONG ] = true,
    [ TAB_TYPEID.ULONG ] = true,
    [ TAB_TYPEID.LLONG ] = true,
    [ TAB_TYPEID.LDOUBLE ] = true,
    [ TAB_TYPEID.LONG ] = true,
    [ TAB_TYPEID.FIXED ] = true,
    [ TAB_TYPEID.VOID ] = true,
    [ TAB_TYPEID.TYPECODE ] = true,
    [ TAB_TYPEID.SEQUENCE ] = true,
    [ TAB_TYPEID.STRING ] = true,
  }
  if ( tab_legal_type[ type ] ) then
    return true
  else
    return false
  end --if
end

local tab_accept_member_type = { 
    [ TAB_TYPEID.INTERFACE ] = true,
    [ TAB_TYPEID.HOME ] = true,
    [ TAB_TYPEID.VALUETYPE ] = true,
    [ TAB_TYPEID.EVENTTYPE ] = true,
}

local tab_accept_definition_type = { 
    [ TAB_TYPEID.MODULE ] = true,
    [ TAB_TYPEID.STRUCT ] = true,
    [ TAB_TYPEID.INTERFACE ] = true,
    [ TAB_TYPEID.UNION ] = true,
    [ TAB_TYPEID.EXCEPTION ] = true,
    [ TAB_TYPEID.HOME ] = true,
    [ TAB_TYPEID.VALUETYPE ] = true,
    [ TAB_TYPEID.EVENTTYPE ] = true,
}

local tab_definition_type = { 
    [ TAB_TYPEID.MODULE ] = true,
    [ TAB_TYPEID.STRUCT ] = true,
    [ TAB_TYPEID.ENUM ] = true,
    [ TAB_TYPEID.INTERFACE ] = true,
    [ TAB_TYPEID.UNION ] = true,
    [ TAB_TYPEID.EXCEPTION ] = true,
    [ TAB_TYPEID.INTERFACE ] = true,
    [ TAB_TYPEID.TYPEDEF ] = true,
    [ TAB_TYPEID.COMPONENT ] = true,
    [ TAB_TYPEID.HOME ] = true, 
    [ TAB_TYPEID.VALUETYPE ] = true,
    [ TAB_TYPEID.EVENTTYPE ] = true,
}

local function is_accept_members( type )
  if ( tab_accept_member_type[ type ] ) then
    return true
  else
    return false
  end --if
end

local function is_accept_definition( type )
  if ( tab_accept_definition_type[ type ] ) then
    return true
  else
    return false
  end --if
end

local function is_definition( type )
  if ( tab_definition_type[ type ] ) then
    return true
  else
    return false
  end --if
end

local function define( name, type )
  local absolutename = get_absolutename( tab_curr_scope, name )
  local tab_scope
  local tab_members
  local tab_definitions
  -- Is there this scope ? Whenever exist and it is a module, then we
  -- must reopen this module...
  if tab_namespaces[ absolutename ] then
    if ( 
        tab_namespaces[ absolutename ].tab_namespace._type == TAB_TYPEID.MODULE
        and
        type == TAB_TYPEID.MODULE 
       ) 
    then
      tab_scope = tab_namespaces[ absolutename ].tab_namespace
      tab_members = tab_namespaces[ absolutename ].tab_namespace.members
      tab_definitions = tab_namespaces[ absolutename ].tab_namespace.definitions
    else
      sem_error( string.format( ERRMSG_REDEFINITION, name ) )
    end --if
  end --if

  if tab_forward[ absolutename ] then
    tab_scope = tab_forward[ absolutename ]
    tab_forward[ absolutename ] = nil
  end --if
    
  local curr_root  = get_scope( 'curr_root' )
  local curr_scope = get_scope( 'curr_scope' )
  
  local prefix = tab_prefix_pragma_stack[ table.getn( tab_prefix_pragma_stack ) ]
  if tab_namespaces[ tab_curr_scope.absolute_name ].prefix then
    curr_root = prefix
  end --if

  if type == TAB_TYPEID.MODULE then
    if curr_root ~= '' then curr_root = curr_root..'::' end
    curr_root = curr_root..name
  else
    if curr_scope ~= '' then curr_scope = curr_scope..'::' end
    curr_scope = curr_scope..name
  end --if
  
  if ( not tab_members and is_accept_members( type ) ) then
    tab_members = { }
  end --if
  
  if not tab_scope then
    tab_scope = { }
  end --if
  
  if ( not tab_definitions and is_accept_definition( type ) ) then
    tab_definitions = { }
  end --if
  
  local separator
  if curr_root ~= '' and curr_scope ~= '' then
    separator = '/'
  else
    separator = ''
  end --if
  tab_scope.name = name
  tab_scope.absolute_name = absolutename
  tab_scope._type = type
  tab_scope.repID = "IDL:"..string.gsub( curr_root, '::', '/' )..separator..string.gsub( curr_scope, '::', '/' )..
  ":"..lex.version_pragma
  tab_scope.members = tab_members
  tab_scope.definitions = tab_definitions
  if ( is_definition( type ) and tab_curr_scope ~= tab_output ) then
    tab_curr_scope.definitions[ name ] = tab_scope
  else
    table.insert( tab_curr_scope, tab_scope )
  end --if
   
  tab_namespaces[ absolutename ] = { 
                                      father_scope = tab_curr_scope, 
                                      tab_namespace = tab_scope,
                                      curr_root = curr_root,
                                      curr_scope = curr_scope
                                   }
  tab_curr_scope = tab_scope
end

local function get_tab_legal_type( namespace )
  local tab_scope = tab_curr_scope
  while true do
    local absolutename = get_absolutename( tab_scope, namespace )
    if ( type( tab_namespaces[ absolutename ] ) == 'table' ) then
      return tab_namespaces[ absolutename ].tab_namespace
    end -- if
    local forward = tab_forward[ absolutename ]
    if forward then
      return forward
    end --if
    if tab_scope._type == TAB_TYPEID.INTERFACE then
      for _, v in ipairs( tab_scope ) do
        tab_scope = tab_namespaces[ v.absolute_name ].tab_namespace
        absolutename = get_absolutename( tab_scope, namespace )
        if ( type( tab_namespaces[ absolutename ] ) == 'table' ) then
          return tab_namespaces[ absolutename ].tab_namespace
        end -- if      
        local forward = tab_forward[ absolutename ]
        if forward then
          return forward
        end --if
      end -- for
    end -- if
    if tab_scope ~= tab_output then
      tab_scope = tab_namespaces[ tab_scope.absolute_name ].father_scope
    else
      break
    end -- if
  end -- while
    sem_error( string.format( ERRMSG_UNDECLARED, namespace ) )
end

local function get_tab_global_legal_type( global_namespace )
  local absolutename = '::'..global_namespace
  if ( type( tab_namespaces[ absolutename ] ) == 'table' ) then
    return tab_namespaces[ absolutename ].tab_namespace
  end --if
  local forward = tab_forward[ absolutename ]
  if forward then
    return forward
  end --if
  sem_error( string.format( ERRMSG_UNDECLARED, global_namespace ) )
end

local function get_tab_legal_type_spec(fullnamespace)
  if ( type( tab_namespaces[ fullnamespace ] ) == 'table' ) then
    return tab_namespaces[ fullnamespace ].tab_namespace
  end -- if
  local forward = tab_forward[ fullnamespace ]
  if forward then
    return forward
  end --if
  sem_error( string.format( ERRMSG_UNDECLARED, fullnamespace ) )
end

local function get_token()
  token = lex.lexer( stridl )

  for _, linemark in ipairs( lex.tab_linemarks ) do
    if linemark[ '1' ] then
      tab_namespaces[ tab_curr_scope.absolute_name ].prefix = true
      table.insert( tab_prefix_pragma_stack, '' )
    elseif linemark[ '2' ] then
      table.remove( tab_prefix_pragma_stack )
    end --if
  end --for
  lex.tab_linemarks = { }
  
  if token == lex.tab_tokens.TK_PRAGMA_ID then    
    token = lex.lexer( stridl )
    local tab_scope = scoped_name( 600 )
    local repid = lex.tokenvalue
    reconhecer_sem_pragma( lex.tab_tokens.TK_STRING_LITERAL, 'string literal' ) 
    local absolutename = tab_scope.absolute_name
    if tab_namespaces[ absolutename ].pragmaID then
      if tab_scope.repID ~= repid then
        sem_error( "repository ID ever defined" )
      end --if
    else
      tab_namespaces[ absolutename ].pragmaID = true
      tab_scope.repID = repid
    end --if
    token = get_token()
  elseif token == lex.tab_tokens.TK_PRAGMA_PREFIX then
    token = lex.lexer( stridl )
    reconhecer_sem_pragma( lex.tab_tokens.TK_STRING_LITERAL, "string literal" )
    local prefix_pragma = lex.tokenvalue
    if tab_namespaces[ tab_curr_scope.absolute_name ].prefix then
      table.remove( tab_prefix_pragma_stack )
    end --if
    --tab_namespaces[ tab_curr_scope.absolute_name ].prefix = prefix_pragma
    tab_namespaces[ tab_curr_scope.absolute_name ].prefix = true
    table.insert( tab_prefix_pragma_stack, prefix_pragma )
    token = get_token()
  end --if
  return token
end

local function dclForward( name, type)
  local absolute_name = get_absolutename( tab_curr_scope, name )
  local def = tab_namespaces[ absolute_name ] or tab_forward[ absolute_name ]
  if not def then
    def = { name = name, _type = type, absolute_name = absolute_name }
    tab_forward[ absolute_name ] = def
  end --if
  return def
end

local function is_int( const )
  return string.find( const, '[%d]' )
end

local function is_num( const )
  return tonumber( const )
end

function reconhecer_sem_pragma( token_expected, value_expected )
  if token_expected ~= token then
    sin_error( value_expected )
  end --if
end

function reconhecer( token_expected, value_expected )
  if token_expected == token then
    token = get_token()
  else
    sin_error( value_expected )
  end --if
end

local tab_ERRORMSG = 
  {
    [01] = "definition ('typedef', 'enum', 'native', 'union', 'struct', "..
           "'const', 'exception', 'abstract', 'local', "..
           "'interface', 'custom', 'valuetype', 'eventtype', "..
           "'module', 'typeid', 'typeprefix', 'component' or 'home')",
    [02] = "type declaration ( 'typedef', 'struct', 'union', 'enum' or 'native' )",
    [03] = "type specification ( 'char', 'boolean', 'octet', 'any', 'Object', "..
           "'ValueBase', 'long', 'float', 'double', 'short', 'unsigned', 'sequence', "..
           "'string', 'fixed', identifier, 'struct', 'union', 'enum' )",
    [04] = "simple type specification ( base type, template type or a scoped name )",
    [05] = "base type specification ( 'char', 'boolean', 'octet', 'any', 'Object', "..
           "'ValueBase', 'long', 'float', 'double', 'short', 'unsigned' )",
    [06] = "'float', 'double', 'short', 'unsigned' or 'long'",
    [07] = "'float' or 'double'",
    [08] = "'short' or 'unsigned'",
    [09] = "'long' or 'short'",
  --follows!?
    [10] = "'long'",
    [11] = "',' or ';'",
    [12] = "'[', ',' or ';'",
    [13] = "'-', '+', '~', '(', identifier, ':', <integer literal>,"..
           "<string literal>, <char literal>, <fixed literal>,"..
           "<float literal>, 'TRUE' or 'FALSE'",
    [14] = "'-', '+', '~'",
    [15] = "'(', identifier, ':', <integer literal>,"..
           "<string literal>, <char literal>, <fixed literal>,"..
           "<float literal>, 'TK_TRUE', 'TK_FALSE'",
    [16] = "<integer literal>, <string literal>, <char literal>,"..
           "<fixed literal>, <float literal>",
    [17] = "'TK_TRUE', 'TK_FALSE'",
    [18] = "'*', '/', '%', '+', '-', ']', ')', '>>', '<<', '&', '^', '|'",
    [19] = "'+', '-', '>>', '<<'",
    [20] = "'>>', '<<', '&'",
    [21] = "'&', '^'",
    [22] = "'^', '|'",
    [23] = "'|'",
    [24] = "you must entry with a positive integer",
    [25] = "you must entry with a integer",
    [26] = "'<' or identifier",
    [27] = "constructed type specification ( 'struct', 'union' or 'enum' )",
    [28] = "type specification or '}'",
    [29] = "'short', 'unsigned', 'char', 'boolean', 'enum', identifier, '::'",
    [30] = "'case', 'default'",
    [31] = "'case', 'default' or type specification",
    [32] = "'case', 'default' or '}'",
  }

local specification, definition_l, definition_l_r, definition, type_dcl, type_declarator,
      type_spec, simple_type_spec, base_type_spec, floating_type_or_int_type,
      floating_pt_type, integer_type, unsigned_int, unsigned_int_tail,
      long_e, declarator_l, declarator_l_r, declarator, fixed_array_size_l, fixed_array_size,
      positive_int_const, xor_expr, and_expr, shift_expr, add_expr, mult_expr, unary_expr,
      unary_operator, primary_expr, literal, boolean_literal, mult_expr_l, add_expr_l, 
      shift_expr_l, and_expr_l, xor_expr_l, or_expr_l, template_type_spec, sequence_type,
      sequence_type_tail, string_type, string_type_tail, fixed_pt_type, constr_type_spec,
      struct_type, member_l, member, member_r, union_type, switch_type_spec, case_l, case,
      case_label_l, case_label, case_label_l_r, case_l_r, element_spec, component, component_tail

-- ok2
-- disable import declaration
function specification()
--  import_l()
  definition_l()
end	

-- ok2
function definition_l()
  if tab_firsts.rule_11[ token ] then
    definition()
    definition_l_r()
  else
  --ok2
    sin_error( tab_ERRORMSG[ 01 ] )
  end --if
end

-- ok2
function definition_l_r()
  if tab_firsts.rule_12[ token ] then
    definition()
    definition_l_r()
  elseif token == nil then
    --empty
  else
    sin_error( tab_ERRORMSG[ 01 ] )
  end --if
end

function definition()
  if tab_firsts.rule_14[ token ] then
    type_dcl()
    reconhecer( ";", "';'" )
  elseif tab_firsts.rule_15[ token ] then
    const_dcl()
    reconhecer( ";", "';'" )
  elseif tab_firsts.rule_16[ token ] then
    except_dcl()
    reconhecer( ";", "';'" )
  elseif tab_firsts.rule_17[ token ] then
    inter_value_event()
    reconhecer( ";", "';'" )
  elseif tab_firsts.rule_18[ token ] then
    module()
    reconhecer( ";", "';'" )
  elseif tab_firsts.rule_19[ token ] then
    type_id_dcl()
    reconhecer( ";", "';'" )
  elseif tab_firsts.rule_20[ token ] then
    type_prefix_dcl()
    reconhecer( ";", "';'" )
  elseif tab_firsts.rule_21[ token ] then
    component()
    reconhecer( ";", "';'" )
  elseif tab_firsts.rule_22[ token ] then
    home_dcl()
    reconhecer( ";", "';'" )
  end --if
end

function const_dcl()
  if tab_firsts.rule_174[ token ] then
    reconhecer( lex.tab_tokens.TK_CONST, "'const'" )
    local tab_type = const_type()
    reconhecer( lex.tab_tokens.TK_ID, "'identifier'" )
    local const_name = lex.tokenvalue_previous
    define( const_name, TAB_TYPEID.CONST )
    tab_curr_scope.type = tab_type
    reconhecer( '=', "'='" )
    local value = positive_int_const( 143 )
    tab_curr_scope.value = value
    local tab_constscope = tab_curr_scope
    goto_father_scope()
    if tab_callbacks.const then
      tab_callbacks.const( tab_constscope )
    end --if
  end --if
end

function const_type()
  if tab_firsts.rule_175[ token ] then
    return float_type_or_int_type()
  elseif tab_firsts.rule_176[ token ] then
    reconhecer( lex.tab_tokens.TK_CHAR, "'char'" )
    return TAB_BASICTYPE.CHAR
  elseif tab_firsts.rule_177[ token ] then
    reconhecer( lex.tab_tokens.TK_BOOLEAN, "'boolean'" )
    return TAB_BASICTYPE.BOOLEAN
  elseif tab_firsts.rule_178[ token ] then
    reconhecer( lex.tab_tokens.TK_STRING, "'string'" )
    return TAB_BASICTYPE.STRING
  elseif tab_firsts.rule_179[ token ] then
    return scoped_name( 32 )
  elseif tab_firsts.rule_180[ token ] then
    reconhecer( lex.tab_tokens.TK_OCTET, "'octet'" )
    return TAB_BASICTYPE.OCTET
  elseif tab_firsts.rule_181[ token ] then
    reconhecer( lex.tab_tokens.TK_FIXED, "'fixed'" )   
    return TAB_BASICTYPE.FIXED
  end
end


function type_dcl()
  if tab_firsts.rule_23[ token ] then
    reconhecer( lex.tab_tokens.TK_TYPEDEF, "'typedef'" )
    --local tab_dcls = type_declarator()
    type_declarator()
--    if tab_callbacks.typedef then
--      tab_callbacks.typedef( tab_dcls )
--    end --if
  elseif tab_firsts.rule_24[ token ] then
    local tab_enumscope = enum_type()
    if tab_callbacks.enum then
      tab_callbacks.enum( tab_enumscope )
    end --if
  elseif tab_firsts.rule_25[ token ] then
    reconhecer( lex.tab_tokens.TK_NATIVE, "'native'" )
    reconhecer( lex.tab_tokens.TK_ID, "identifier" )
    local name = lex.tokenvalue_previous
    define( name, TAB_TYPEID.NATIVE )
    local tab_nativescope = tab_curr_scope
    goto_father_scope()
    if tab_callbacks.native then
      tab_callbacks.native( tab_nativescope )
    end --if
  elseif tab_firsts.rule_26[ token ] then
    union_or_struct()
  else
    sin_error( tab_ERRORMSG[ 02 ] )
  end --if
end

function type_declarator()
  local tab_type = type_spec()
  if not is_legal_type( tab_type._type ) then
    sem_error( string.format( ERRMSG_NOTTYPE, tab_type._type ) )
  end --if
  return type_dcl_name_l( tab_type )
end

function type_spec()
  if tab_firsts.rule_28[ token ] then
    return simple_type_spec()
  elseif tab_firsts.rule_29[ token ] then
    return constr_type_spec()
  else
    sin_error( tab_ERRORMSG[ 03 ] )
  end --if
end

function simple_type_spec( numrule )
  if tab_firsts.rule_30[ token ] then
    return base_type_spec()
  elseif tab_firsts.rule_31[ token ] then
    return template_type_spec()
  elseif tab_firsts.rule_32[ token ] then 
    return scoped_name( numrule or 32 )
  else
    sin_error( tab_ERRORMSG[ 04 ] )
  end --if
end

function base_type_spec()
  if tab_firsts.rule_36[ token ] then
    return float_type_or_int_type()
  elseif tab_firsts.rule_37[ token ] then
    reconhecer( lex.tab_tokens.TK_CHAR, "'char'" )
    return TAB_BASICTYPE.CHAR
  elseif tab_firsts.rule_38[ token ] then
    reconhecer( lex.tab_tokens.TK_BOOLEAN, "'boolean'" )
    return TAB_BASICTYPE.BOOLEAN
  elseif tab_firsts.rule_39[ token ] then
    reconhecer( lex.tab_tokens.TK_OCTET, "'octet'" )
    return TAB_BASICTYPE.OCTET
  elseif tab_firsts.rule_40[ token ] then
    reconhecer( lex.tab_tokens.TK_ANY, "'any'" )
    return TAB_BASICTYPE.ANY
  elseif tab_firsts.rule_41[ token ] then
    reconhecer( lex.tab_tokens.TK_OBJECT, "'Object'" )
    return TAB_BASICTYPE.OBJECT
  elseif tab_firsts.rule_42[ token ] then
    reconhecer( lex.tab_tokens.TK_VALUEBASE, "'ValueBase'" )
    return TAB_BASICTYPE.VALUEBASE
  elseif token == lex.tab_tokens[ 'TK_TYPECODE' ] then
    reconhecer( lex.tab_tokens.TK_TYPECODE, "'TypeCode'" )
    return TAB_BASICTYPE.TYPECODE
--  else
--    sin_error( tab_ERRORMSG[ 05 ] )
  end --if
end

function float_type_or_int_type()
  if tab_firsts.rule_43[ token ] then
    return floating_pt_type()
  elseif tab_firsts.rule_44[ token ] then
    return integer_type( 54 )
  elseif tab_firsts.rule_45[ token ] then
    reconhecer( lex.tab_tokens.TK_LONG, "'long'" )
    return long_or_double()
  else
    sin_error( tab_ERRORMSG[ 06 ] )
  end -- if
end

function floating_pt_type()
  if tab_firsts.rule_46[ token ] then
    reconhecer( lex.tab_tokens.TK_FLOAT, "'float'" )
    return TAB_BASICTYPE.FLOAT
  elseif tab_firsts.rule_47[ token ] then
    reconhecer( lex.tab_tokens.TK_DOUBLE, "'double'" )
    return TAB_BASICTYPE.DOUBLE
--  else
--    sin_error( tab_ERRORMSG[ 07 ] ) 
  end --if
end

function integer_type( numrule )
  if tab_firsts.rule_48[ token ] then
    reconhecer( lex.tab_tokens.TK_SHORT, "'short'" )
    return TAB_BASICTYPE.SHORT
  elseif tab_firsts.rule_49[ token ] then
    return unsigned_int( numrule )
--  else
--    sin_error( tab_ERRORMSG[ 08 ] )
  end --if
end

function unsigned_int( numrule )
  reconhecer( lex.tab_tokens.TK_UNSIGNED, "'unsigned'" )
  return unsigned_int_tail( numrule )
end

function unsigned_int_tail( numrule )
  if tab_firsts.rule_51[ token ] then
    reconhecer( lex.tab_tokens.TK_LONG, "'long'" )
    return long_e( numrule )
  elseif tab_firsts.rule_52[ token ] then
    reconhecer( lex.tab_tokens.TK_SHORT, "'short'" )
    return TAB_BASICTYPE.USHORT
  else
    sin_error( tab_ERRORMSG[ 09 ] )
  end --if
end

function long_e( numrule )
  if tab_firsts.rule_53[ token ] then
    reconhecer( lex.tab_tokens.TK_LONG, "'long'" )
    return TAB_BASICTYPE.ULLONG
  elseif tab_follow[ 'rule_'..numrule ][ token ] then
    return TAB_BASICTYPE.ULONG
    --empty
  else
    sin_error( tab_ERRORMSG[ 10 ] )
  end --if
end

function type_dcl_name_l( tab_type_spec )
  local tab_dcls = { }
  type_dcl_name( tab_type_spec, tab_dcls )
  type_dcl_name_l_r( tab_type_spec, tab_dcls )
  return tab_dcls
end

function type_dcl_name_l_r( tab_type_spec, tab_dcls )
  if tab_firsts.rule_142[ token ] then
    reconhecer( ",", "','" )
    type_dcl_name( tab_type_spec, tab_dcls )
    type_dcl_name_l_r( tab_type_spec, tab_dcls )
  elseif tab_follow.rule_143 [ token ] then
    --empty
  else
    sin_error( tab_ERRORMSG[ 11 ] )
  end --if
end

function type_dcl_name( tab_type_spec, tab_dcls )
  reconhecer( lex.tab_tokens.TK_ID, "identifier" )
  define( lex.tokenvalue_previous, TAB_TYPEID.TYPEDEF )
  tab_curr_scope.type = fixed_array_size_l( tab_type_spec )
  tab_curr_scope.name = lex.tokenvalue_previous
  --tab_dcls[lex.tokenvalue_previous] = tab_curr_scope
  if tab_callbacks.typedef then
    tab_callbacks.typedef( tab_curr_scope )
  end --if
  goto_father_scope()
end

function declarator_l( tab_type_spec, tab_dcls )
  declarator( tab_type_spec, tab_dcls )
  declarator_l_r( tab_type_spec, tab_dcls )
end

function declarator_l_r( tab_type_spec, tab_dcls )
  if tab_firsts.rule_142[ token ] then
    reconhecer( ",", "','" )
    declarator( tab_type_spec, tab_dcls )
    declarator_l_r( tab_type_spec, tab_dcls )
  elseif tab_follow.rule_143 [ token ] then
    --empty
  else
    sin_error( tab_ERRORMSG[ 11 ] )
  end --if
end

function declarator( tab_type_spec, tab_dcls )
  reconhecer( lex.tab_tokens.TK_ID, "identifier" )
  local name = lex.tokenvalue_previous
  dclName( name, tab_curr_scope )
  local type = fixed_array_size_l( tab_type_spec )
  table.insert( tab_curr_scope, { name =  name, type = type } )
  tab_dcls[ name ] = type
end

function fixed_array_size_l( tab_type_spec )
  if tab_firsts.rule_145[ token ] then
    local array =  { 
             length = fixed_array_size( tab_type_spec ), 
             elementtype = fixed_array_size_l( tab_type_spec ), 
             _type = 'array' 
           }
    if tab_callbacks.array then
      tab_callbacks.array( array )
    end --if    
    return array
  elseif tab_follow.rule_146[ token ] then
    --empty
    return tab_type_spec
  else 
    sin_error( tab_ERRORMSG[ 12 ] )
  end --if
end

function fixed_array_size( tab_type_spec )
  reconhecer( "[", "'['" )
  local const = positive_int_const( 147 )
  reconhecer( "]", "']'" )
  return const
end

--without revision
--without bitwise logical operations
function positive_int_const( numrule )
  if tab_firsts.rule_75[ token ] then
    local const1 = xor_expr( numrule )
    or_expr_l( numrule )
    if is_int( const1 ) then
     const1 = tonumber(const1) 
     if const1 < 0 then
        sem_error( tab_ERRORMSG[ 24 ] )
      end --if
    end --if
    return const1
  else
    sin_error( tab_ERRORMSG[ 13 ] )
  end --if
end

--ok2
function xor_expr( numrule )
  if tab_firsts.rule_93[ token ] then
    local exp1 = and_expr( numrule )
    xor_expr_l( numrule )
    return exp1
--  else
--    sin_error( tab_ERRORMSG[ 13 ] )
  end --if
end

--ok2
function and_expr( numrule )
  if tab_firsts.rule_96[ token ] then
    local const1 = shift_expr( numrule )
    return and_expr_l( const1, numrule )
--  else
--    sin_error( tab_ERRORMSG[ 13 ] )
  end --if
end

--ok2
function shift_expr( numrule )
  if tab_firsts.rule_99[ token ] then
    local const1 = add_expr( numrule )
    return shift_expr_l( const1, numrule )
--  else
--    sin_error( tab_ERRORMSG[ 13 ] )
  end --if
end

--ok2
function add_expr( numrule )
  if tab_firsts.rule_103[ token ] then
    local const1 = mult_expr( numrule )
    return add_expr_l( const1, numrule ) 
--  else
--    sin_error( tab_ERRORMSG[ 13 ] )
  end --if
end

--ok2
function mult_expr( numrule )
  if tab_firsts.rule_107[ token ] then
    local const = unary_expr()
--[[    if not is_num( const ) then
      sem_error( tab_ERRORMSG[ 25 ] )
    end --if
]]
    const = mult_expr_l( const, numrule )
    return const
--  else
--    sin_error( tab_ERRORMSG[ 13 ] )
  end --if
end

--ok2
--semantic of '~' operator ???!!
function unary_expr()
  if tab_firsts.rule_112[ token ] then
    local op = unary_operator()
    local exp = primary_expr()
    if is_num( exp ) then
      if op == '-' then
        exp = tonumber( '-'..exp )
      elseif op == '+' then
        exp = tonumber( '+'..exp )
      end --if
    end --if
    return exp
  elseif tab_firsts.rule_113[ token ] then
    return primary_expr()
--  else
--    sin_error( tab_ERRORMSG[ 13 ] )
  end --if
end

--ok2
function unary_operator()
  if tab_firsts.rule_114[ token ] then
    reconhecer( "-", "'-'" )
    return '-'
  elseif tab_firsts.rule_115[ token ] then
    reconhecer( "+", "'+'" )
    return '+'
  elseif tab_firsts.rule_116[ token ] then
    reconhecer( "~", "'~'" )
    return '~'
--  else
--    sin_error( tab_ERRORMSG[ 14 ] )
  end --if
end

function scoped_name_primaryexp_l( tab_scope, full_namespace, num_follow_rule )
  if token == ":" then
    reconhecer( ":" , "':'" )
    if token ~= ":" then
      return tab_scope.value
    end --if
    reconhecer( ":" , "':'" )
    reconhecer( lex.tab_tokens.TK_ID , "identifier" )
    local namespace = lex.tokenvalue_previous
    label = namespace
    full_namespace = tab_scope.absolute_name..'::'..namespace
    if ( type( tab_namespaces[ full_namespace ] ) == 'table' ) then
      tab_scope = tab_namespaces[ full_namespace ].tab_namespace
    else
--      sem_error(  string.format( ERRMSG_UNDECLARED, full_namespace ) )
      return namespace
    end --if
    scoped_name_primaryexp_l( tab_scope, full_namespace, num_follow_rule )
  elseif ( tab_follow[ 'rule_'..num_follow_rule ][ token ] ) then
    -- empty
  else
    sin_error( "':' or "..tab_follow_rule_error_msg[ num_follow_rule ] )
  end
--  return tab_scope
  return tab_scope.value
end

function scoped_name_primaryexp( num_follow_rule )
  local namespace = ''
  local tab_scope = { }
  if token == lex.tab_tokens.TK_ID then
    reconhecer( lex.tab_tokens.TK_ID, "identifier" )
    local namespace = lex.tokenvalue_previous
    label = namespace
    tab_scope = get_tab_legal_type( namespace )
    tab_scope = scoped_name_primaryexp_l( tab_scope, namespace, num_follow_rule )
  elseif token == ":" then
    reconhecer( ":", "':'" )
    if token ~= ":" then
      return tab_scope.value
--      return tab_scope
    end --if
    reconhecer( ":", "':'" )
    reconhecer( lex.tab_tokens.TK_ID, "identifier" )
    local namespace = lex.tokenvalue_previous
    tab_scope = get_tab_global_legal_type( namespace )
    tab_scope = scoped_name_primaryexp_l( tab_scope, namespace, num_follow_rule )
  end
  return tab_scope
end

function primary_expr()
  if tab_firsts.rule_117[ token ] then
    return scoped_name_primaryexp( 147 )
  elseif tab_firsts.rule_118[ token ] then
    return literal()
  elseif tab_firsts.rule_119[ token ] then
    reconhecer( "(", "'('" )
    local const = positive_int_const( 119 )
    reconhecer( ")", "')'" )
    return const
  else 
    sin_error( tab_ERRORMSG[ 15 ] )
  end --if
end

function literal()
  if tab_firsts.rule_120[ token ] then
    reconhecer( lex.tab_tokens.TK_INTEGER_LITERAL, "<integer literal>" )
    return lex.tokenvalue_previous
  elseif tab_firsts.rule_121[ token ] then
    reconhecer( lex.tab_tokens.TK_STRING_LITERAL, "<string literal>" )
    return lex.tokenvalue_previous
  elseif tab_firsts.rule_122[ token ] then
    reconhecer( lex.tab_tokens.TK_CHAR_LITERAL, "<char literal>" )
    return lex.tokenvalue_previous
  elseif tab_firsts.rule_123[ token ] then
    reconhecer( lex.tab_tokens.TK_FIXED_LITERAL, "<fixed literal>" )
    return lex.tokenvalue_previous
  elseif tab_firsts.rule_124[ token ] then
    reconhecer( lex.tab_tokens.TK_FLOAT_LITERAL, "<float literal>" )
    return lex.tokenvalue_previous
  elseif tab_firsts.rule_125[ token ] then
    return boolean_literal()
--  else
--    sin_error( tab_ERRORMSG[ 16 ] )
  end --if
end

--ok2
function boolean_literal()
  if tab_firsts.rule_126[ token ] then
    reconhecer( lex.tab_tokens.TK_TRUE, "'TRUE'" )
    return lex.tokenvalue_previous
  elseif tab_firsts.rule_127[ token ] then
    reconhecer( lex.tab_tokens.TK_FALSE, "'FALSE'" )
    return lex.tokenvalue_previous
--  else
--    sin_error( tab_ERRORMSG[ 17 ] )
  end --if
end

--ok2
function mult_expr_l( const1, numrule )
  if tab_firsts.rule_108[ token ] then
    reconhecer( "*", "'*'" )
    local const2 = unary_expr()
    if not is_num( const2 ) then
      sem_error( tab_ERRORMSG[ 25 ] )
    end --if
    local const = const1 * const2
    return mult_expr_l( const, numrule )
  elseif tab_firsts.rule_109[ token ] then
    reconhecer( "/", "'/'" )
    local const2 = unary_expr()
    if not is_num( const2 ) then
      sem_error( tab_ERRORMSG[ 25 ] )
    end --if
    local const = const1 / const2
    return mult_expr_l( const, numrule )
  elseif tab_firsts.rule_110[ token ] then
    reconhecer( "%", "'%'" )
    local const2 = unary_expr()
    if not is_num( const2 ) then
      sem_error( tab_ERRORMSG[ 25 ] )
    end --if
    local const = math.mod( const1, const2 )
    return mult_expr_l( const, numrule )
  elseif ( tab_follow.rule_111[ token ] or tab_follow[ 'rule_'..numrule ][ token ] or ( lex.tokenvalue_previous == ':' )) then
    --empty
    return const1
  else
    sin_error( tab_ERRORMSG[ 18 ] )
  end --if
end

function add_expr_l( const1, numrule )
  if tab_firsts.rule_104[ token ] then
    reconhecer( "+", "'+'" )
    if not is_num( const1 ) then
      sem_error( tab_ERRORMSG[ 25 ] )
    end --if
    local const2 = mult_expr( numrule )
    local const = const1 + const2
    return add_expr_l( const, numrule )
  elseif tab_firsts.rule_105[ token ] then
    reconhecer( "-", "'-'" )
    if not is_num( const1 ) then
      sem_error( tab_ERRORMSG[ 25 ] )
    end --if
    local const2 = mult_expr( numrule )
    local const = const1 - const2
    return add_expr_l( const, numrule )
  elseif ( tab_follow.rule_106[ token ] or tab_follow[ 'rule_'..numrule ][ token ] or ( lex.tokenvalue_previous == ':' ) ) then
    --empty
    return const1
  else
    sin_error( tab_ERRORMSG[ 19 ] )
  end --if
end

--
function shift_expr_l( const1, numrule )
  if tab_firsts.rule_100[ token ] then
    reconhecer( ">>", "'>>'" )
    add_expr( numrule )
    shift_expr_l( numrule )
  elseif tab_firsts.rule_101[ token ] then
    reconhecer( "<<", "'<<'" )
    add_expr( numrule )
    shift_expr_l( numrule )
  elseif ( tab_follow.rule_102[ token ] or tab_follow[ 'rule_'..numrule ][ token ] or ( lex.tokenvalue_previous == ':' )) then
    --empty
    return const1
  else
    sin_error( tab_ERRORMSG[ 20 ] )
  end --if
end

--
function and_expr_l( const1, numrule )
  if tab_firsts.rule_97[ token ] then
    reconhecer( "&", "'&'" )
--[[    if not is_num( const1 ) then
      sem_error( tab_ERRORMSG[ 25 ] )
    end --if]]
    local const2 = shift_expr( numrule )
--    local const = const1 and const2
    return and_expr_l( const, numrule )
  elseif ( tab_follow.rule_98[ token ] or tab_follow[ 'rule_'..numrule ][ token ] or ( lex.tokenvalue_previous == ':' ) ) then
    --empty
    return const1
  else
    sin_error( tab_ERRORMSG[ 21 ] )
  end --if  
end

--
function xor_expr_l( numrule )
  if tab_firsts.rule_94[ token ] then
    reconhecer( "^", "'^'" )
    and_expr( numrule )
    xor_expr_l( numrule )
  elseif ( tab_follow.rule_95[ token ] or tab_follow[ 'rule_'..numrule ][ token ] or ( lex.tokenvalue_previous == ':' ) ) then
    --empty
  else
    sin_error( tab_ERRORMSG[ 22 ] )
  end --if    
end

--
function or_expr_l( numrule )
  if tab_firsts.rule_91[ token ] then
    reconhecer( "|", "'|'" )
    xor_expr( numrule )
    or_expr_l( numrule )
  elseif ( tab_follow[ 'rule_'..numrule ][ token ] or ( lex.tokenvalue_previous == ':' ) ) then
    --empty
  else
    sin_error( tab_ERRORMSG[ 23 ] )
  end --if    
end

function template_type_spec()
  if tab_firsts.rule_58[ token ] then
    return sequence_type()
  elseif tab_firsts.rule_59[ token ] then
    return string_type()
  elseif tab_firsts.rule_60[ token ] then
    return fixed_pt_type()
  end --if
end

function sequence_type()
  reconhecer( lex.tab_tokens.TK_SEQUENCE, "'sequence'" )
  reconhecer( "<", "'<'" )
  local tab_type_spec = simple_type_spec( 61 )
  tab_type_spec = sequence_type_tail( tab_type_spec )
  if tab_callbacks.sequence then
    tab_callbacks.sequence( tab_type_spec )
  end --if
  return tab_type_spec
end

function sequence_type_tail( tab_type_spec )
  if tab_firsts.rule_69[ token ] then
    reconhecer( ",", "','" )
    local const = positive_int_const( 69 )
    reconhecer( ">", "'>'" )
    return { _type = TAB_TYPEID.SEQUENCE, elementtype = tab_type_spec, maxlength = const  }
  elseif tab_firsts.rule_70[ token ] then
    reconhecer( ">", "'>'" )
  --maxlength??
    return { _type = TAB_TYPEID.SEQUENCE, elementtype = tab_type_spec, maxlength = 0  }
  else
    sin_error( "',' or '>'" )
  end --if
end

--ok2
function string_type()
  reconhecer( lex.tab_tokens.TK_STRING, "'string'" )
--maxlength??
  return { _type = TAB_TYPEID.STRING, maxlength = 0
  --size = string_type_tail() 
  }
end

--ok2
function string_type_tail()
  if tab_firsts.rule_72[ token ] then
    reconhecer( "<", "'<'" )
    local const = positive_int_const( 72 )
    reconhecer( ">", "'>'" )
    return const
  elseif tab_follow.rule_73[ token ] then
    return nil
    --empty
  else
    sin_error( tab_ERRORMSG[ 26 ] )
  end --if
end

--const1 and const2 ??!?
function fixed_pt_type()
  reconhecer( lex.tab_tokens.TK_FIXED, "'fixed'" )
  reconhecer( "<", "'<'" )
  local const1 = positive_int_const( 74 )
  reconhecer( ",", "','" )
  local const2 = positive_int_const( 74 )
  reconhecer( ">", "'>'" )
  return TAB_BASICTYPE.FIXED
end

function constr_type_spec()
  if tab_firsts.rule_33[ token ] then
    return struct_type()
  elseif tab_firsts.rule_34[ token ] then
    return union_type()
  elseif tab_firsts.rule_35[ token ] then
    return enum_type()
  else
    sin_error( tab_ERRORMSG[ 27 ] )
  end --if
end

function struct_type()
  reconhecer( lex.tab_tokens.TK_STRUCT, "'struct'" )
  reconhecer( lex.tab_tokens.TK_ID, "identifier" )
  define( lex.tokenvalue_previous, TAB_TYPEID.STRUCT )
  local tab_struct = tab_curr_scope
  tab_curr_scope.fields = tab_curr_scope
  reconhecer( "{", "'{'" )
  member_l()
  local tab_structscope = tab_curr_scope
  goto_father_scope()
  reconhecer( "}", "'}'" )
  if tab_callbacks.struct then
    tab_callbacks.struct( tab_structscope )
  end --if
  return tab_struct
end

function member_l()
  if tab_firsts.rule_137[ token ] then
    member()
    member_r()
  else
    sin_error( tab_ERRORMSG[ 03 ] )
  end --if
end

function member()
  if tab_firsts.rule_140[ token ] then
    local tab_dcls = { }
    declarator_l( type_spec(), tab_dcls )
    reconhecer( ";", "';'" ) 
  else
    sin_error( tab_ERRORMSG[ 03 ] )
  end --if
end

function member_r()
  if tab_firsts.rule_138[ token ] then
    member()
    member_r()
  elseif tab_follow.rule_139[ token ] then
    -- empty
  else
    sin_error( tab_ERRORMSG[ 28 ] )
  end --if
end

function union_type()
  if tab_firsts.rule_148[ token ] then
    reconhecer( lex.tab_tokens.TK_UNION, "'union'" )
    reconhecer( lex.tab_tokens.TK_ID, "identifier" )
    local union_name = lex.tokenvalue_previous
    reconhecer( lex.tab_tokens.TK_SWITCH, "'switch'" )
    define( union_name, TAB_TYPEID.UNION )
    reconhecer( "(", "'('" )
    tab_curr_scope.switch = switch_type_spec()
    tab_curr_scope.options = { }
    reconhecer( ")", "')'" )
    reconhecer( "{" )
    tmp = -1
    case_l()
    tab_curr_scope.default = tmp
    reconhecer( "}" )
    local tab_unionscope = tab_curr_scope
    goto_father_scope()
    if tab_callbacks.union then
      tab_callbacks.union( tab_unionscope )
    end --if
    return tab_unionscope
  else
    sin_error( tab_ERRORMSG[ 29 ] )
  end --if
end

function switch_type_spec()
  if tab_firsts.rule_149[ token ] then
    return integer_type( 148 )
  elseif tab_firsts.rule_150[ token ] then
    reconhecer( lex.tab_tokens.TK_LONG, "'long'" )
    return long_e( 148 )
  elseif tab_firsts.rule_151[ token ] then
    reconhecer( lex.tab_tokens.TK_CHAR, "'char'" )
    return TAB_BASICTYPE.CHAR
  elseif tab_firsts.rule_152[ token ] then
    reconhecer( lex.tab_tokens.TK_BOOLEAN, "'boolean'" )
    return TAB_BASICTYPE.BOOLEAN
  elseif tab_firsts.rule_153[ token ] then
    reconhecer( lex.tab_tokens.TK_ENUM, "'enum'" )
    return TAB_BASICTYPE.ENUM
  elseif tab_firsts.rule_154[ token ] then
    return scoped_name( 154 )
  else
    sin_error( tab_ERRORMSG[ 30 ] )
  end -- if
end

function case_l()
  if tab_firsts.rule_155[ token ] then
    case()
    case_l_r()
  else
    sin_error( tab_ERRORMSG[ 31 ] )
  end --if
end

function case()
  if tab_firsts.rule_158[ token ] then
    case_label_l()
    element_spec()
    reconhecer( ";", "';'" )
  else
    sin_error( tab_ERRORMSG[ 31 ] )
  end --if
end

function case_label_l()
  local cases = { }
  if tab_firsts.rule_159[ token ] then
    case_label()
    case_label_l_r()
  else
    sin_error( tab_ERRORMSG[ 31 ] )
  end --if
  return cases
end

function case_label()
  if tab_firsts.rule_162[ token ] then
    reconhecer( lex.tab_tokens.TK_CASE, "'case'" )
    local value = positive_int_const( 162 )
    if ( not label ) then
      label = value
    end --if
    dclName( label, tab_curr_scope)
    table.insert( tab_curr_scope.options, { label = label } )
    label = nil
    if ( lex.tokenvalue_previous ~= ':' ) then
      reconhecer( ":", "':'" )
    end --if
  elseif tab_firsts.rule_163[ token ] then
    reconhecer( lex.tab_tokens.TK_DEFAULT, "'default'" )
    dclName( 'none', tab_curr_scope)
    table.insert( tab_curr_scope.options, { label = 'none' } )
    reconhecer( ":", "':'" )
    tmp = table.getn( tab_curr_scope.options )
  else
    sin_error( tab_ERRORMSG[ 31 ] )
  end -- if
end

--
function case_label_l_r()
  if tab_firsts.rule_160[ token ] then
    case_label()
    case_label_l_r()
  elseif tab_follow.rule_161[ token ] then
    --empty
  else 
    sin_error( tab_ERRORMSG[ 32 ] )
  end --if
end

function case_l_r()
  if tab_firsts.rule_156[ token ] then
    case()
    case_l_r()
  elseif tab_follow.rule_157[ token ] then
    --empty
  else
    sin_error( tab_ERRORMSG[ 33 ] )
  end --if
end

function element_spec()
  if tab_firsts.rule_164[ token ] then
    local tab_type_spec = type_spec()
    reconhecer( lex.tab_tokens.TK_ID, "identifier" )
    dclName( lex.tokenvalue_previous, tab_curr_scope )
    local x = table.getn( tab_curr_scope.options )
    while ( x > 0 and not tab_curr_scope.options[ x ].name ) do
      tab_curr_scope.options[ x ].name = lex.tokenvalue_previous
      tab_curr_scope.options[ x ].type = tab_type_spec
      x = x - 1
    end --while
  else
    sin_error( tab_ERRORMSG[ 03 ] )
  end --if
end

function enum_type()
  reconhecer( lex.tab_tokens.TK_ENUM, "'enum'" )
  reconhecer( lex.tab_tokens.TK_ID, "identifier" )
  local enum_name = lex.tokenvalue_previous
  define( enum_name, TAB_TYPEID.ENUM )
  tab_curr_scope.enumvalues = tab_curr_scope
  local tab_enumscope = tab_curr_scope
  reconhecer( "{", "'{'" )
  enumerator()
  enumerator_l()
  reconhecer( "}", "'}'" )
  goto_father_scope()
  return tab_enumscope
end

function enumerator()
  reconhecer( lex.tab_tokens.TK_ID, "identifier" )
  local enum_name = lex.tokenvalue_previous
  local tab_namespace = { }
  dclName( enum_name, tab_curr_scope, tab_namespace )
  table.insert( tab_curr_scope, enum_name )
  tab_namespace.value = table.getn( tab_curr_scope )
end

function enumerator_l()
  if tab_firsts.rule_166[ token ] then
    reconhecer( ",", "','" )
    enumerator()
    enumerator_l()
  elseif tab_follow.rule_167[ token ] then
    -- empty
  else
    sin_error( "',' or '}'" )
  end --if
end

function module()
  if tab_firsts.rule_305[ token ] then
    reconhecer( lex.tab_tokens.TK_MODULE, "'module'" )
    reconhecer( lex.tab_tokens.TK_ID, "identifier" )
    local modulename = lex.tokenvalue_previous
    define( modulename, TAB_TYPEID.MODULE )
    reconhecer( "{", "'{'" )
    definition_l_module()
    local tab_modulescope = tab_curr_scope
    goto_father_scope()
    reconhecer( "}" , "'}'" )
    if tab_callbacks.module then
      tab_callbacks.module( tab_modulescope )
    end --if
  end -- if
end

function long_or_double()
  if tab_firsts.rule_55[ token ] then
    reconhecer(lex.tab_tokens.TK_LONG, "'long'")
    return TAB_BASICTYPE.LLONG
  elseif tab_firsts.rule_56[ token ] then
    reconhecer(lex.tab_tokens.TK_DOUBLE, "'double'")
    return TAB_BASICTYPE.LDOUBLE
  else
    return TAB_BASICTYPE.LONG
  end -- if
end

function scoped_name_l( tab_scope, full_namespace, num_follow_rule )
  if token == ":" then
    reconhecer( ":" , "':'" )
    reconhecer( ":" , "':'" )
    reconhecer( lex.tab_tokens.TK_ID , "identifier" )
    local namespace = lex.tokenvalue_previous
    full_namespace = tab_scope.absolute_name..'::'..namespace
    tab_scope = get_tab_legal_type_spec(full_namespace)
    tab_scope = scoped_name_l( tab_scope, full_namespace, num_follow_rule )
  elseif ( tab_follow[ 'rule_'..num_follow_rule ][ token ] ) then
    -- empty
  else
    sin_error( "':' or "..tab_follow_rule_error_msg[ num_follow_rule ] )
  end
  return tab_scope
end

function scoped_name( num_follow_rule )
  local namespace = ''
  local tab_scope = { }
  if token == lex.tab_tokens.TK_ID then
    reconhecer( lex.tab_tokens.TK_ID, "identifier" )
    local namespace = lex.tokenvalue_previous
    tab_scope = get_tab_legal_type( namespace )
    tab_scope = scoped_name_l( tab_scope, namespace, num_follow_rule )
  elseif token == ":" then
    reconhecer( ":", "':'" )
    reconhecer( ":", "':'" )
    reconhecer( lex.tab_tokens.TK_ID, "identifier" )
    local namespace = lex.tokenvalue_previous
    tab_scope = get_tab_global_legal_type( namespace )
    tab_scope = scoped_name_l( tab_scope, namespace, num_follow_rule )
  end
  return tab_scope
end

-- falta struct forward
function struct_tail()
  if ( tab_firsts.rule_170[ token ] ) then
    reconhecer( "{", "'{'" )
    member_l()
    reconhecer( "}", "'}'" )
  elseif token == ";" then
    -- empty
  else
    sin_error( " '{' or ';' " )
  end -- if
end

function union_tail()
  if ( tab_firsts.rule_172[ token ] ) then
    reconhecer( lex.tab_tokens.TK_SWITCH, "'switch'" )
    reconhecer( "(", "'('" )
    tab_curr_scope.switch  = switch_type_spec()
    tab_curr_scope.options = { }
    reconhecer( ")", "')'" )
    reconhecer( "{", "'{'" )
    tmp = -1
    case_l()
    tab_curr_scope.default = tmp
    reconhecer( "}", "'}'" )
    --return tab_curr_scope[ union_name ]
  else
    sin_error( "'switch'" )
  end -- if
end

function union_or_struct()
  if ( tab_firsts.rule_168[ token ] ) then
    reconhecer( lex.tab_tokens.TK_STRUCT, "'struct'" )
    reconhecer( lex.tab_tokens.TK_ID, "identifier" )
    local structname = lex.tokenvalue_previous
    define( structname, TAB_TYPEID.STRUCT )
    tab_curr_scope.fields = tab_curr_scope
    struct_tail()
    local tab_structscope = tab_curr_scope
    goto_father_scope()
    if tab_callbacks.struct then
      tab_callbacks.struct( tab_structscope )
    end --if
    return tab_structscope
  elseif ( tab_firsts.rule_169[ token ] ) then
    reconhecer( lex.tab_tokens.TK_UNION, "'union'" )
    reconhecer( lex.tab_tokens.TK_ID, "identifier" )
    local unionname = lex.tokenvalue_previous
    define( unionname, TAB_TYPEID.UNION )
    union_tail()
    local tab_unionscope = tab_curr_scope
    goto_father_scope()
    if tab_callbacks.union then
      tab_callbacks.union( tab_unionscope )
    end --if
    return tab_unionscope
  else
    sin_error( "'struct' or 'union'" )
  end -- if
end

-- Fi Fo OK1
function except_dcl()
  reconhecer(lex.tab_tokens.TK_EXCEPTION, "'exception'")
  reconhecer( lex.tab_tokens.TK_ID, "identifier" )
  local exception_name = lex.tokenvalue_previous
  define( exception_name, TAB_TYPEID.EXCEPTION )
  tab_curr_scope.members = tab_curr_scope
  reconhecer( "{", "'{'" )
  member_l_empty()
  local tab_exceptscope = tab_curr_scope
  goto_father_scope()
  reconhecer( "}", "'}'" )
  if tab_callbacks.except then
    tab_callbacks.except( tab_exceptscope )
  end --if
  return tab_curr_scope[ exception_name ]
end

-- Fi Fo OK1
function member_l_empty()
  if ( tab_firsts.rule_187[ token ] ) then
    member()
    member_l_empty()
  elseif ( token == "}" ) then
    -- empty
  else
    sin_error( "member list { ... } or '}'" )
  end -- if
end


-- Fi Fo OK1
function definition_l_r_module()
  if ( tab_firsts.rule_12[ token ] ) then
    definition()
    definition_l_r_module()
  elseif ( token == '}' ) then
    -- empty
  else
    sin_error( "definition" )
  end -- if
end

-- Fi Fo OK1
function definition_l_module()
  if ( tab_firsts.rule_11[ token ] ) then
    definition()
    definition_l_r_module()
  else
    sin_error( "definition" )
  end -- if
end

function abstract_tail()
  if tab_firsts.rule_195[ token ] then
    reconhecer( lex.tab_tokens.TK_INTERFACE, "'interface'" )
    reconhecer( lex.tab_tokens.TK_ID, "identifier" )
    local name = lex.tokenvalue_previous
    local tab_interfacescope = interface_tail( name, { ['abstract'] = true } )    
    if tab_callbacks.interface then
      tab_callbacks.interface( tab_interfacescope )
    end --if
  elseif tab_firsts.rule_196[ token ] then
    reconhecer( lex.tab_tokens.TK_VALUETYPE, "'valuetype'" )
    reconhecer( lex.tab_tokens.TK_ID, "identifier" )
    local name = lex.tokenvalue_previous
    define( name, TAB_TYPEID.VALUETYPE )
    tab_curr_scope.abstract = true
    local tab_valuetypescope = value_tail( name )
    if tab_callbacks.valuetype then
      tab_callbacks.valuetype( tab_valuetypescope )
    end --if    
  elseif tab_firsts.rule_197[ token ] then
    reconhecer( lex.tab_tokens.TK_EVENTTYPE, "'eventtype'" )
    reconhecer( lex.tab_tokens.TK_ID, "identifier" )
    local name = lex.tokenvalue_previous
    define( name, TAB_TYPEID.EVENTTYPE )
    tab_curr_scope.abstract = true
    local tab_eventtypescope = eventtype_tail( name )
    if tab_callbacks.eventtype then
      tab_callbacks.eventtype( tab_eventtypescope )
    end --if
  else
    sin_error( "'interface', 'valuetype' or 'event'" )
  end --if
end

function inter_value_event()
  if ( tab_firsts.rule_192[ token ] ) then
    reconhecer( lex.tab_tokens.TK_INTERFACE, "'interface'" )
    reconhecer( lex.tab_tokens.TK_ID, "identifier" )
    local name = lex.tokenvalue_previous
    local tab_interfacescope = interface_tail( name )
    if tab_callbacks.interface then
      tab_callbacks.interface( tab_interfacescope )
    end --if
  elseif ( tab_firsts.rule_189[ token ] ) then
    reconhecer( lex.tab_tokens.TK_ABSTRACT, "'abstract'" )
    abstract_tail()
  elseif ( tab_firsts.rule_190[ token ] ) then
    reconhecer( lex.tab_tokens.TK_LOCAL, "'local'" )
    reconhecer( lex.tab_tokens.TK_INTERFACE, "'interface'" )
    reconhecer( lex.tab_tokens.TK_ID, "identifier" )
    local name = lex.tokenvalue_previous
    local tab_interfacescope = interface_tail( name, { ['local'] = true } )
    if tab_callbacks.interface and tab_interfacescope then
      tab_callbacks.interface( tab_interfacescope )
    end --if
  elseif ( tab_firsts.rule_193[ token ] ) then
    reconhecer( lex.tab_tokens.TK_VALUETYPE, "'valuetype'" )
    reconhecer( lex.tab_tokens.TK_ID, "identifier" )
    local name = lex.tokenvalue_previous
    define( name, TAB_TYPEID.VALUETYPE )
    local tab_valuetypescope = value_tail( name )
    if tab_callbacks.valuetype then
      tab_callbacks.valuetype( tab_valuetypescope )
    end --if
  elseif ( tab_firsts.rule_191[ token ] ) then
    reconhecer( lex.tab_tokens.TK_CUSTOM, "'custom'" )
    value_or_event()
  elseif tab_firsts.rule_194[ token ] then
    reconhecer( lex.tab_tokens.TK_EVENTTYPE, "'eventtype'" )
    reconhecer( lex.tab_tokens.TK_ID, "identifier" )
    local name = lex.tokenvalue_previous
    define( name, TAB_TYPEID.EVENTTYPE )
    local tab_eventtypescope = eventtype_tail(name)
    if tab_callbacks.eventtype then
      tab_callbacks.eventtype( tab_eventtypescope )
    end --if
  else
    sin_error( "'interface', 'abstract', 'local' or 'valuetype'" )
  end --if
end

function store_ops_attrs( tab_interface_inh, tab_ops_attrs_inh )
  for _, v in ipairs( tab_interface_inh ) do
    if ( v._type == TAB_TYPEID.ATTRIBUTE
        or
        v._type == TAB_TYPEID.OPERATION
      ) then
      if ( tab_ops_attrs_inh[ v.name ] ) then
        sem_error( "redefinition of '"..v.name.."'."..
                " You do not redefine an operation or attribute, of a derived interface"
        )
      else
        tab_ops_attrs_inh[ v.name ] = true
        new_name( v.name, v.name, tab_curr_scope, v, ERRMSG_REDEFINITION )
      end -- if
    else
      tab_namespaces [ tab_curr_scope.absolute_name.."::"..string.gsub( v.absolute_name, ".*::(.*)", "%1" )] = { tab_namespaces = tab_namespaces[ v.absolute_name ], inherited = true }
    end -- if
  end -- for
end

-- Fi Fo OK1
function inter_name_seq2()
  if ( tab_firsts.rule_254[ token ] ) then
    reconhecer( ",", "','" )
    local tab_base = scoped_name( 204 )
    table.insert( tab_curr_scope, tab_base )
    inter_name_seq2()
  elseif token == '{' then
    -- empty
  else
    sin_error( "',' or '{'" )
	  end -- if
end 

function verifyFlag( flag )
  if flag then
    if flag['local'] then
      tab_curr_scope['local'] = true
    elseif flag.abstract then
      tab_curr_scope.abstract = true
    end --if
  end --if
end

function interface_tail( interface_name, flag )
  if ( tab_firsts.rule_198[ token ] ) then
    reconhecer( ":", "':'" )
    local tab_base = scoped_name( 204 )
    define( interface_name, TAB_TYPEID.INTERFACE )
    table.insert( tab_curr_scope, tab_base )
    inter_name_seq2()
    reconhecer( "{", "'{'" )
    export_l()
    reconhecer( "}", "'}'" )
    local tab_interfacescope = tab_curr_scope
    verifyFlag( flag )
    goto_father_scope()
    return tab_interfacescope
  elseif ( tab_firsts.rule_199[ token ] ) then
    reconhecer( "{", "'{'" )
    define( interface_name, TAB_TYPEID.INTERFACE )
    export_l()
    reconhecer( "}", "'}'" )
    local tab_interfacescope = tab_curr_scope
    verifyFlag( flag )
    goto_father_scope()
    return tab_interfacescope
  elseif ( token == ';' ) then
    return dclForward( interface_name, TAB_TYPEID.INTERFACE )
--    tab_forward[ get_absolutename( tab_curr_scope, interface_name ) ] = { }
    -- empty
  else
    sin_error( "'{', ':' or ';'" )
  end -- if
end

-- Fi Fo
function export_l()
  if tab_firsts.rule_207[ token ] then
    export()
    export_l()
  elseif token == "}" then
    --empty
  else
    sin_error( "empty interface, a declaration or '}'" )
  end
end

-- Fi Fo
-- falta implementar: attr_dcl, constants, type_id e type_prefix
function export()
  if tab_firsts.rule_209[ token ] then
    type_dcl()
    reconhecer( ";", "';'" )
  elseif tab_firsts.rule_211[ token ] then
    except_dcl()
    reconhecer( ";", "';'" )
  elseif tab_firsts.rule_212[ token ] then
    attr_dcl()
    reconhecer( ";", "';'" )
  elseif tab_firsts.rule_213[ token ] then
    op_dcl()
    reconhecer( ";", "';'" )
  else
    sin_error( "constant, type, exception, attribute or operation declaration" )
  end --if
end

-- Fi Fo
-- falta ver as restri��es sem�nticas de oneway
function op_dcl()
  if tab_firsts.rule_243[ token ] then
    reconhecer( lex.tab_tokens.TK_ONEWAY, "'oneway'" )
    local result_type = op_type_spec()
    if result_type._type ~= 'void' then
      sem_error( "An operation with the oneway attribute must specify a 'void' return type." )
    end --if
    reconhecer( lex.tab_tokens.TK_ID, "identifier" )
    local operation_name = lex.tokenvalue_previous
    local tab_op = { _type = TAB_TYPEID.OPERATION, name = operation_name,
                     oneway = true }
    new_name( operation_name, operation_name,
           tab_curr_scope.members, tab_op, ERRMSG_OPDECLARED, operation_name )
    parameter_dcls( tab_op )
    raises_expr_e( tab_op )
    context_expr_e( tab_op )
    if tab_callbacks.operation then 
      tab_callbacks.operation( tab_op )
    end --if
  elseif tab_firsts.rule_244[ token ] then
    local result_type = op_type_spec()
    reconhecer( lex.tab_tokens.TK_ID, "identifier" )
    local operation_name = lex.tokenvalue_previous
    if result_type == 'void' then 
      result_type = nil 
    end --if
    local tab_op = { _type = TAB_TYPEID.OPERATION, name = operation_name,
                result = result_type }
    new_name( operation_name, operation_name,
           tab_curr_scope.members, tab_op, ERRMSG_OPDECLARED, operation_name )
    parameter_dcls( tab_op )
    raises_expr_e( tab_op )
    context_expr_e( tab_op )
    if tab_callbacks.operation then 
      tab_callbacks.operation( tab_op )
    end --if
  else
    sin_error( "'oneway' or type specification" )
  end --if
end

-- Fi Fo OK1
function op_type_spec()
  if ( tab_firsts.rule_245[ token ] ) then
    return param_type_spec()
  elseif tab_firsts.rule_246[ token ] then
    reconhecer( lex.tab_tokens.TK_VOID, "'void'" )
    return TAB_BASICTYPE.VOID
  else
    sin_error( "type return" )
  end --if
end

-- Fi Fo OK1
function parameter_dcls( tab_op )
  reconhecer( "(", "'('" )
  parameter_dcls_tail( tab_op )
end

-- Fi Fo OK1
function parameter_dcls_tail( tab_op )
  if ( tab_firsts.rule_248[ token ] ) then
    tab_op.parameters = { }
    param_dcl( tab_op )
    param_dcl_l( tab_op )
    reconhecer( ")", "')'" )
  elseif ( tab_firsts.rule_249[ token ] ) then
    reconhecer( ")", "')'" )
  else
    sin_error( "'in', 'out', 'inout' or ')'" )
  end -- if
end

-- Fi Fo OK1
function param_dcl( tab_op )
  local attribute = param_attribute()
  local tab_type_spec = param_type_spec()
  reconhecer( lex.tab_tokens.TK_ID, "identifier" )
  local param_name = lex.tokenvalue_previous
  new_name( tab_op.name..'._parameters.'..param_name,
         param_name, tab_op.parameters,
         { mode = 'PARAM_'..string.upper( attribute ), type = tab_type_spec, name = param_name },
         ERRMSG_PARAMDECLARED 
  )
end

-- Fi
function param_dcl_l( tab_op )
  if ( tab_firsts.rule_254[ token ] ) then
    reconhecer( ",", "','" )
    param_dcl( tab_op )
    param_dcl_l( tab_op )
  elseif --token == lex.tab_tokens.TK_RAISES or 
       --token == lex.tab_tokens.TK_CONTEXT or 
       token == ')' then
    -- empty
  else
    sin_error( "',', ')'" )
  end -- if
end 

-- Fi Fo OK1
function param_attribute()
  if ( tab_firsts.rule_251[ token ] ) then
    reconhecer( lex.tab_tokens.TK_IN, "'in'" )
    return 'in'
  elseif ( tab_firsts.rule_252[ token ] ) then
    reconhecer( lex.tab_tokens.TK_OUT, "'out'" )
    return 'out'
  elseif ( tab_firsts.rule_253[ token ] ) then
    reconhecer( lex.tab_tokens.TK_INOUT, "'inout'" )
    return 'inout'
  end --if
end

-- Fi Fo
function param_type_spec()
  if ( tab_firsts.rule_219[ token ] ) then
    return base_type_spec()    
  elseif ( tab_firsts.rule_220[ token ] ) then
    return string_type()
  elseif ( tab_firsts.rule_221[ token ] ) then
    return scoped_name( 221 )
  else
    sin_error( 'type specification' )
  end -- if
end

function raises( tab_op )
  local tab_raises = scoped_name( 229 )
  if tab_raises._type ~= TAB_TYPEID.EXCEPTION then
    sem_error( string.format( "The type of '%s' is %s, but it should be exception.",
          tab_raises.absolute_name, tab_raises._type ) )
  end -- if
  new_name( tab_op.name..'_raises.'..tab_raises.absolute_name,
         tab_raises.absolute_name, tab_op.exceptions, tab_raises,
         ERRMSG_RAISESDECLARED, tab_raises.repID
  )
end

-- Fi Fo OK1
function inter_name_seq( tab_op )
  if ( tab_firsts.rule_254[ token ] ) then
    reconhecer( ",", "','" )
    raises( tab_op )
    inter_name_seq( tab_op )
  elseif token == ')' then
    -- empty
  else
    sin_error( "')'" )
  end -- if
end 

-- Fi Fo OK1
function raises_expr( tab_op )
  reconhecer( lex.tab_tokens.TK_RAISES, "'raises'" )
  reconhecer( "(", "'('" )
  tab_op.exceptions = { }
  raises( tab_op )
  inter_name_seq( tab_op )
  reconhecer( ")", "')'" )
end

-- Fi Fo OK1
function raises_expr_e( tab_op )
  if ( tab_firsts.rule_370[ token ] ) then
    raises_expr( tab_op )
  elseif token == ';' or token == lex.tab_tokens.TK_CONTEXT then
    -- empty
  else
    sin_error( "'raises', 'context', ';'" )
  end -- if
end

-- Fi Fo OK1
function context( tab_op )
  reconhecer( lex.tab_tokens.TK_STRING_LITERAL, "string literal" )
  local string = lex.tokenvalue_previous
  new_name( '_context.'..string, string,
         tab_op.context, string, ERRMSG_DECLARED )
end

-- Fi Fo OK1
function string_literal_l( tab_op )
  if ( tab_firsts.rule_257[ token ] ) then
    reconhecer( ",", "','" )
    context( tab_op )
    string_literal_l( tab_op )
  elseif token == ')' then
    -- empty
  else
    sin_error( "',' or ')'" )
  end -- if
end

-- Fi Fo 
-- sem regras semanticas...
function context_expr( tab_op )
  reconhecer( lex.tab_tokens.TK_CONTEXT, "'context'" )
  reconhecer( "(", "'('" )
  tab_op.context = { }
  context( tab_op )
  string_literal_l( tab_op )
  reconhecer( ")", "')'" )
end

-- Fi Fo OK1
function context_expr_e( tab_op )
  if ( tab_firsts.rule_377[ token ] ) then
    context_expr( tab_op )
  elseif token == ';' then
    -- empty
  else
    sin_error( "'context' or ';'" )
  end -- if

end

-- Fi Fo OK1
function attr_dcl( tab_dest )
  if ( tab_firsts.rule_216[ token ] ) then
    readonly_attr_spec( tab_dest )
  elseif ( tab_firsts.rule_217[ token ] ) then
    attr_spec( tab_dest )
  else
    sin_error( "'readonly' or 'attribute'" )
  end -- if
end

-- Fi Fo
function readonly_attr_spec( tab_dest )
  reconhecer( lex.tab_tokens.TK_READONLY, "'readonly'" )
  reconhecer( lex.tab_tokens.TK_ATTRIBUTE, "'attribute'" )
  local tab_type_spec = param_type_spec()
  local tab_attr = readonly_attr_spec_dec( tab_type_spec, tab_dest )
  if tab_callbacks.attribute then
    tab_callbacks.attribute( tab_attr )
  end --if
end

-- Fi Fo OK1    
function attr_spec( tab_dest )
  reconhecer( lex.tab_tokens.TK_ATTRIBUTE, "'attribute'" )
  local tab_type_spec = param_type_spec()
  local tab_attr = attr_declarator( tab_type_spec, tab_dest )
  if tab_callbacks.attribute then
    tab_callbacks.attribute( tab_attr )
  end --if
end

function readonly_attr_spec_dec( tab_type_spec, tab_dest )
  local tab_attr = { _type = TAB_TYPEID.ATTRIBUTE , type = tab_type_spec, readonly = true }
  simple_dcl( tab_attr )
  --provisorio...
  if not tab_dest then
    tab_dest = tab_curr_scope.members
  end --if
  new_name( tab_attr.name, tab_attr.name, tab_dest, tab_attr, ERRMSG_DECLARED, tab_attr.name )
  readonly_attr_spec_dec_tail( tab_attr )
  return tab_attr
end

-- Fi Fo
function attr_declarator( tab_type_spec, tab_dest  )
  local tab_attr = { _type = TAB_TYPEID.ATTRIBUTE , type = tab_type_spec }
  simple_dcl( tab_attr )
  --provisorio...
  if not tab_dest then
    tab_dest = tab_curr_scope.members
  end --if
  new_name( tab_attr.name, tab_attr.name, tab_dest, tab_attr, ERRMSG_DECLARED, tab_attr.name )
  attr_declarator_tail( tab_attr )
  return tab_attr
end

-- Fi Fo
function readonly_attr_spec_dec_tail( tab_attr )
  if ( tab_firsts.rule_227[ token ] ) then
    tab_attr.raises = { }
    raises_expr( tab_attr )
  elseif ( tab_firsts.rule_228[ token ] ) then
    simple_dcl_l( tab_attr )
  elseif ( token == ';' ) then
    -- empty
  else
    sin_error( "'raises', ',' or ';'" )
  end -- if
end

-- Fi Fo
function attr_declarator_tail( tab_attr )
  if ( tab_firsts.rule_234[ token ] ) then
    attr_raises_expr( tab_attr )
  elseif ( tab_firsts.rule_235[ token ] ) then
    simple_dcl_l( tab_attr )
  elseif ( token == ';' ) then
    -- empty
  else
    sin_error( "'getraises', 'setraises', ',' or ';'" )
  end -- if
end

-- Fi Fo OK1
function simple_dcl( tab_attr )
  reconhecer( lex.tab_tokens.TK_ID, "identifier" )
  tab_attr.name = lex.tokenvalue_previous
end

-- Fi Fo OK1
function simple_dcl_l( t )
  if ( tab_firsts.rule_142[ token ] ) then
    reconhecer( ",", "','" )
    local tab_attr = { }
    for k, v in pairs( t ) do
      tab_attr[ k ] = v
    end --for
    simple_dcl( tab_attr )
    new_name( tab_attr.name, tab_attr.name, tab_curr_scope.members, 
              tab_attr, ERRMSG_DECLARED, tab_attr.name )
    simple_dcl_l( t )
  elseif ( token == ';' ) then
    -- empty
  end -- if
end

function attr_raises_expr( tab_attr )
  if ( tab_firsts.rule_236[ token ] ) then
    reconhecer( lex.tab_tokens.TK_GETRAISES, "'getraises'" )
    tab_attr.getraises = { }
    exception_l( tab_attr, 'getraises' )
    attr_raises_expr_tail( attribute_name )
  elseif ( tab_firsts.rule_237[ token ] ) then
    reconhecer( lex.tab_tokens.TK_SETRAISES, "'setraises'" )
    tab_attr.setraises = { }
    exception_l( tab_attr, 'setraises' )  
  end -- if
end

function exception( tab_attr, raises_type )
  local tab_scope = scoped_name( 229 )
  new_name( '_'..raises_type..'.'..tab_scope.absolute_name, tab_scope.absolute_name,
         tab_attr[ raises_type ], tab_scope, ERRMSG_DECLARED 
  )
end

-- Fi Fo OK1
function exception_l_seq( tab_attr, raises_type )
  if ( tab_firsts.rule_142[ token ] ) then
    reconhecer( ",", "','" )
    exception( tab_attr, raises_type )
    exception_l_seq( tab_attr, raises_type )
  elseif ( token == ';' ) then
    -- empty
  end -- if
end

function exception_l( attribute_name, raises_type )
  reconhecer( "(", "'('" )
  exception( attribute_name, raises_type )
  exception_l_seq( attribute_name, raises_type )
  reconhecer( ")", "')'" )
end

--------------------------------------------------------------------------
-- COMPONENT DECLARATION
--------------------------------------------------------------------------

--17
function component()
  reconhecer( lex.tab_tokens.TK_COMPONENT, "'component'" )
  reconhecer( lex.tab_tokens.TK_ID, "identifier" )
  local name = lex.tokenvalue_previous
  define( name, TAB_TYPEID.COMPONENT )
  tab_curr_scope.declarations = { }
  component_tail( name )
  goto_father_scope()
end

function component_tail( name )
--17
  if ( tab_firsts.rule_307[ token ] ) then
    reconhecer(":", "':'")
    local component = scoped_name( 307 )
    if component._type ~= TAB_TYPEID.COMPONENT then
      sem_error( "The previously-defined type is not a COMPONENT" )
    end --if
	  tab_curr_scope.component_base = component
    supp_inter_spec(308)
    reconhecer( "{", "'{'" )
    component_body()
    reconhecer( "}", "'}'" )
--17
  elseif ( tab_firsts.rule_308[ token ] ) then
    supp_inter_spec(308)
    reconhecer( "{", "'{'" )
    component_body()
    reconhecer( "}", "'}'" )
--17
  elseif ( tab_firsts.rule_309[ token ] ) then
    reconhecer( "{", "'{'" )
    component_body()
    reconhecer( "}", "'}'" )
  elseif ( token == ';' ) then
    dclForward( name, TAB_TYPEID.COMPONENT )
    --empty
--17
  else
    sin_error( "':', 'supports' or '{'" )
  end --if
end

--17
function supp_inter_spec(num_follow_rule)
  if tab_firsts.rule_316[ token ] then
    reconhecer( lex.tab_tokens.TK_SUPPORTS, "'supports'" )
    tab_curr_scope.supports = { }
    local interface = scoped_name( num_follow_rule )
    if interface._type ~= TAB_TYPEID.INTERFACE then
      sem_error( "The 'SUPPORTS' construction must be reference to an interface" )
    end --if
    table.insert( tab_curr_scope.supports, interface )
    supp_name_list(num_follow_rule)
  elseif ( tab_follow[ 'rule_'..num_follow_rule ][ token ] ) then
    -- empty
  else
    sin_error( "':', ',', or "..tab_follow_rule_error_msg[ num_follow_rule ] )
  end
end 

--17
function supp_name_list(num_follow_rule)
  if ( tab_firsts.rule_321[ token ] ) then
    reconhecer( ',', "','" )
    local interface = scoped_name( num_follow_rule )
    if interface._type ~= TAB_TYPEID.INTERFACE then
      sem_error( "The 'SUPPORTS' construction must be reference to an interface" )
    end --if
    table.insert( tab_curr_scope.supports, interface )
    supp_name_list(num_follow_rule)
  elseif ( tab_follow[ 'rule_'..num_follow_rule ][ token ] ) then
    --empty
  else
    sin_error( "',' or '{'" )
  end --if
end

function component_body()
  if ( tab_firsts.rule_323[ token ] ) then
    component_export()
    component_body()
  elseif ( token == '}' ) then
    --empty
  else
    sin_error( "'provides', 'uses', 'emits', 'publishes', 'consumes', 'readonly' 'attribute' or '}'" )
  end --if
end

function component_export()
  if ( tab_firsts.rule_325[ token ] ) then
    provides_dcl()
    reconhecer( ';', "';'" )
  elseif ( tab_firsts.rule_326[ token ] ) then
    uses_dcl()
    reconhecer( ';', "';'" )
  elseif ( tab_firsts.rule_327[ token ] ) then
    emits_dcl()
    reconhecer( ';', "';'" )
  elseif ( tab_firsts.rule_328[ token ] ) then
    publishes_dcl()
    reconhecer( ';', "';'" )
  elseif ( tab_firsts.rule_329[ token ] ) then
    consumes_dcl()
    reconhecer( ';', "';'" )
  elseif ( tab_firsts.rule_330[ token ] ) then
    attr_dcl( tab_curr_scope.declarations )
    reconhecer( ';', "';'" )
  end
end

function provides_dcl()
  reconhecer( lex.tab_tokens.TK_PROVIDES, 'provides' )
  local tab_provides = { _type = 'provides' }
  tab_provides.interface_type = interface_type()
  reconhecer( lex.tab_tokens.TK_ID, '<identifier>' )
  local name = lex.tokenvalue_previous
  new_name( name, name, tab_curr_scope.declarations, tab_provides, ERRMSG_DECLARED, name )
end

function interface_type()
  if ( tab_firsts.rule_332[ token ] ) then
    local scope = scoped_name( 332 )
    if scope._type ~= TAB_TYPEID.INTERFACE then
      sem_error( "The interface type of this provides declaration shall be either the keyword Object or a scoped name that denotes a previously-declared interface type" )
    end --if
    return scope
  elseif ( tab_firsts.rule_333[ token ] ) then
    reconhecer( lex.tab_tokens.TK_OBJECT, "'Object'" )
    return TAB_BASICTYPE.OBJECT
  else
    sin_error( "<identifier> or 'Object'" )
  end --if
end

function uses_dcl()
  reconhecer( lex.tab_tokens.TK_USES, "'uses'" )
  local tab_uses = { _type = 'uses' }
  tab_uses.multiple = multiple_e()
  tab_uses.interface_type = interface_type()
  reconhecer( lex.tab_tokens.TK_ID, "<identifier>" )
  local name = lex.tokenvalue_previous
  new_name( name, name, tab_curr_scope.declarations, tab_uses, ERRMSG_DECLARED, name )
end

function multiple_e()
  if ( tab_firsts.rule_339[ token ] ) then
    reconhecer( lex.tab_tokens.TK_MULTIPLE, "'multiple'" )
    return true
  elseif ( tab_follow.rule_340[ token ] ) then
    return nil
    --empty
  else
    sin_error( "'multiple', <identifier>, ':' or 'Object'" )
  end --if
end

--falta event!!
function emits_dcl()
  reconhecer( lex.tab_tokens.TK_EMITS, "'emits'" )
  local name = lex.tokenvalue_previous
  local tab_uses = { _type = 'emits' }
  new_name( name, name, tab_curr_scope.declarations, tab_emits, ERRMSG_DECLARED, name )
  tab_uses.event_type = scoped_name( 341 ) 
  reconhecer( lex.tab_tokens.TK_ID, "<identifier>" )
  tab_uses.evtsrc = lex.tokenvalue_previous
end

--falta event!!
function publishes_dcl()
  reconhecer( lex.tab_tokens.TK_PUBLISHES, "'publishes'" )
  local name = lex.tokenvalue_previous
  local tab_publishes = { _type = 'publishes' }
  new_name( name, name, tab_curr_scope.declarations, tab_publishes, ERRMSG_DECLARED, name )
  tab_uses.event_type = scoped_name( 342 ) 
  reconhecer( lex.tab_tokens.TK_ID, "<identifier>" )
  tab_uses.evtsrc = lex.tokenvalue_previous
end

--falta event!!
function consumes_dcl()
  reconhecer( lex.tab_tokens.TK_CONSUMES, "'consumes'" )
  local name = lex.tokenvalue_previous
  local tab_publishes = { _type = 'consumes' }
  new_name( name, name, tab_curr_scope.declarations, tab_consumes, ERRMSG_DECLARED, name )
  tab_uses.event_type = scoped_name( 343 ) 
  reconhecer( lex.tab_tokens.TK_ID, "<identifier>" )
  tab_uses.evtsink = lex.tokenvalue_previous
end

function attr_raises_expr_tail( attribute_name )
  if ( tab_firsts.rule_238[ token ] ) then
    reconhecer( lex.tab_tokens.TK_SETRAISES, "'setraises'" )
    tab_curr_scope[ attribute_name ].setraises = { }
    exception_l( attribute_name, 'setraises' )  
  elseif ( token == ';' ) then
    --empty
  else
    sin_error( "'setraises' or ';'" )
  end --if
end

--------------------------------------------------------------------------
-- HOME DECLARATION
--------------------------------------------------------------------------

--19
function home_dcl()
  reconhecer(lex.tab_tokens.TK_HOME, "'home'")
  reconhecer(lex.tab_tokens.TK_ID, "'identifier'")
  local name = lex.tokenvalue_previous
  define( name, TAB_TYPEID.HOME )
  home_dcl_tail(name)
  goto_father_scope()
end

--19
--falta primary key
function home_dcl_tail(name)
  if ( tab_firsts.rule_345[ token ] )then
    home_inh_spec()
    supp_inter_spec(345)
    reconhecer(lex.tab_tokens.TK_MANAGES)
    local component = scoped_name(347)
    tab_curr_scope.manages = component
    primary_key_spec_e()
    reconhecer("{", "'{'")
    home_export_l()
    reconhecer("}", "'}'")
  elseif ( tab_firsts.rule_346[ token ] ) then
  	supp_inter_spec(345)
    reconhecer(lex.tab_tokens.TK_MANAGES)
    local component = scoped_name(347)
    tab_curr_scope.manages = component
    primary_key_spec_e()
    reconhecer("{", "'{'")
    home_export_l()
    reconhecer("}", "'}'")
  elseif ( tab_firsts.rule_347[ token ] ) then
    reconhecer(lex.tab_tokens.TK_MANAGES)
    tab_curr_scope.component = scoped_name(347)
    primary_key_spec_e()
    reconhecer("{", "'{'")
    home_export_l()
    reconhecer("}", "'}'")
  else
    sin.error("'supports', 'manages', ':'")
  end --if
end

--19
function home_inh_spec()
  if ( tab_firsts.rule_348[ token ] ) then
  	reconhecer(":","':'")
    local home = scoped_name( 348 )
    if home._type ~= TAB_TYPEID.HOME then
      sem_error( "The previously-defined type is not a HOME" )
    end --if
    tab_curr_scope.home_base = home
  end --if
end

--(353) <primary_key_spec_e>    :=    TK_PRIMARYKEY <scoped_name>
--(354)                         |     empty
function primary_key_spec_e()
  if tab_firsts.rule_353[ token ] then
    reconhecer(lex.tab_tokens.TK_PRIMARYKEY, 'primarykey')
    scoped_name(353)
  elseif tab_follow.rule_353[ token ] then
    --empty
  end --if
end

--19
function home_export_l()
  if tab_firsts.rule_359[ token ] then
  	home_export()
  	home_export_l()
  elseif tab_follow.rule_359[ token ] then
  	--empty
  end --if
end

--19
function home_export()
  if tab_firsts.rule_361[ token ] then
    export()
  elseif tab_firsts.rule_362[ token ] then
  	factory_dcl()
  	reconhecer(";","';'")
  elseif tab_firsts.rule_363[ token ] then
  	finder_dcl()
  	reconhecer(";","';'")
  else
    sin_error("error")
  end --if
end

--19
function factory_dcl()
  if tab_firsts.rule_364[ token ] then
  	reconhecer(lex.tab_tokens.TK_FACTORY, "'factory'")
  	reconhecer(lex.tab_tokens.TK_ID, "'identifier'")
    local name = lex.tokenvalue_previous
    local tab_factory = { _type = TAB_TYPEID.FACTORY, name = name }
    new_name( name, name,
           tab_curr_scope.members, tab_factory, ERRMSG_OPDECLARED, name )
    reconhecer("(","'('")
    init_param_dcls(tab_factory)
    reconhecer(")","')'")
    raises_expr_e(tab_factory)
  end --if
end

--19
function init_param_dcls(tab_factory)
  if tab_firsts.rule_366[ token ] then
    tab_factory.parameters = { }
  	init_param_dcl(tab_factory)
  	init_param_dcl_list(tab_factory)
  elseif tab_follow.rule_367[ token ] then
  	--empty
  end --if
end

--19
function init_param_dcl(tab_factory)
  if tab_firsts.rule_297[ token ] then
  	reconhecer(lex.tab_tokens.TK_IN, "'in'")
  	local tab_type_spec = param_type_spec()
  	reconhecer(lex.tab_tokens.TK_ID, "'identifier'")
    local param_name = lex.tokenvalue_previous
    new_name( tab_factory.name..'._parameters.'..param_name,
           param_name, tab_factory.parameters,
           { mode = 'PARAM_IN', type = tab_type_spec, name = param_name },
           ERRMSG_PARAMDECLARED 
  )
  else
    sin_error("'in'")
  end --if
end

--19
function init_param_dcl_list(tab_factory)
  if tab_firsts.rule_368[ token ] then
  	reconhecer(",", "','")
  	init_param_dcl(tab_factory)
  	init_param_dcl_list(tab_factory)
  elseif tab_follow.rule_369[ token ] then
  	--empty
  end --if
end

--19
function finder_dcl()
  if tab_firsts.rule_365[ token ] then
  	reconhecer(lex.tab_tokens.TK_FINDER, "'finder'")
  	reconhecer(lex.tab_tokens.TK_ID, "'identifier'")
    local name = lex.tokenvalue_previous
    local tab_finder = { _type = TAB_TYPEID.FINDER, name = name }
    new_name( name, name,
           tab_curr_scope.members, tab_finder, ERRMSG_OPDECLARED, name )
  	reconhecer("(", "'('")
  	init_param_dcls(tab_finder)
  	reconhecer(")", "')'")
  	raises_expr_e(tab_finder)
  else
    sin_error("'finder'")
  end --if
end

function value_or_event()
  if ( tab_firsts.rule_281[ token ] ) then
    reconhecer( lex.tab_tokens.TK_VALUETYPE, "'valuetype'" )
    reconhecer( lex.tab_tokens.TK_ID, "identifier" )
    local name = lex.tokenvalue_previous
    define( name, TAB_TYPEID.VALUETYPE )
    tab_curr_scope.custom = true
    local tab_valuetypescope = value_tail( name )
    if tab_callbacks.valuetype then
      tab_callbacks.valuetype( tab_valuetypescope )
    end --if
  elseif ( tab_firsts.rule_282[ token ] ) then
    reconhecer( lex.tab_tokens.TK_EVENTTYPE, "'eventtype'" )
    reconhecer( lex.tab_tokens.TK_ID, "identifier" )
    local name = lex.tokenvalue_previous
    define( name, TAB_TYPEID.EVENTTYPE )
    tab_curr_scope.custom = true
    local tab_eventtypescope = eventtype_tail( name )
    if tab_callbacks.eventtype then
      tab_callbacks.eventtype( tab_eventtypescope )
    end --if
  else
    sin_error( "'valuetype' or 'eventtype'" )
  end --if
end
--------------------------------------------------------------------------
-- VALUE DECLARATION
--------------------------------------------------------------------------

function value_tail( name )
  if ( tab_firsts.rule_299[ token ] ) then
    return value_tail_aux( name )
  elseif ( tab_firsts.rule_298[ token ] ) then
    value_inhe_spec()
    return value_tail_aux( name )
  elseif tab_firsts.rule_300[ token ] then
    tab_curr_scope.type = type_spec()
    local tab_valuetypescope = tab_curr_scope
    goto_father_scope()
    return tab_valuetypescope
  elseif tab_follow.rule_301[ token ] then
    return dclForward( name, TAB_TYPEID.VALUETYPE )
  end --if
end

function value_tail_aux( name )
    reconhecer( "{", "'{'" )
    value_element_l()
    reconhecer( "}", "'}'" )
    local tab_valuetypescope = tab_curr_scope
    goto_father_scope()
    return tab_valuetypescope
end

function value_inhe_spec()
  if tab_firsts.rule_268[ token ] then
    reconhecer( ":", "':'" )
    local truncatable = truncatable_e()
    local value = scoped_name(268)
    if value._type ~= TAB_TYPEID.VALUETYPE and value._type ~= TAB_TYPEID.INTERFACE then
      sem_error( "The previously-defined type is not a VALUETYPE or INTERFACE" )
    end --if
    tab_curr_scope.value_base = { }
    tab_curr_scope.value_base.truncatable = truncatable
    table.insert( tab_curr_scope.value_base, value )
    value_name_list()
    supp_inter_spec(308)
  elseif tab_firsts.rule_269[ token ] then
    supp_inter_spec(308) 
  else
    sin_error( "':', 'supports'" )
  end --if
end

function value_name_list()
  if tab_firsts.rule_277[ token ] then
    reconhecer( ",", "','" )
    local value = scoped_name(268)
    table.insert( tab_curr_scope.value_base, value )
    value_name_list()
  elseif tab_follow.rule_278[ token ] then
    --empty
  end --if
end

function truncatable_e()
  if tab_firsts.rule_271[ token ] then
    reconhecer( lex.tab_tokens.TK_TRUNCATABLE, "'truncatable'" )
    return true
  elseif tab_follow.rule_272[ token ] then
    --empty
  end --if
end

function value_element_l()
  if ( tab_firsts.rule_285[ token ] ) then
    value_element()
    value_element_l()
  elseif ( tab_follow.rule_286[ token ] ) then
    --empty
  end --if
end

function value_element()
  if ( tab_firsts.rule_287[ token ] ) then
    export()
  elseif ( tab_firsts.rule_288[ token ] ) then
    state_member()
  elseif ( tab_firsts.rule_289[ token ] ) then
    init_dcl()
  end --if
end

function state_member()
  if ( tab_firsts.rule_290[ token ] ) then
    reconhecer( lex.tab_tokens.TK_PUBLIC, "'public'" )
    state_member_tail()
  elseif ( tab_firsts.rule_291[ token ] ) then
    reconhecer( lex.tab_tokens.TK_PRIVATE, "'private'" )
    state_member_tail()
  end --if
end

function state_member_tail()
  local tab_dcls = { }
  declarator_l( type_spec(), tab_dcls )
  reconhecer( ";", "';'" )
end

function init_dcl()
  if ( tab_firsts.rule_292[ token ] ) then
    reconhecer(lex.tab_tokens.TK_FACTORY, "'factory'")
    reconhecer(lex.tab_tokens.TK_ID, "'identifier'")
    local name = lex.tokenvalue_previous
    local tab_factory = { _type = TAB_TYPEID.FACTORY, name = name }
    new_name( name, name,
           tab_curr_scope.members, tab_factory, ERRMSG_OPDECLARED, name )
    reconhecer("(","'('")
    init_param_dcls(tab_factory)
    reconhecer(")","')'")
    raises_expr_e(tab_factory)
    reconhecer( ";", "';'" )
  end --if
end

--------------------------------------------------------------------------
-- EVENT DECLARATION
--------------------------------------------------------------------------

function eventtype_tail(name)
  if tab_firsts.rule_302[ token ] then
    value_inhe_spec()
    reconhecer( "{", "'{'" )
    value_element_l()
    reconhecer( "}", "'}'" )
    local tab_eventtypescope = tab_curr_scope
    goto_father_scope()
    return tab_eventtypescope
  elseif tab_firsts.rule_303[ token ] then
    reconhecer( "{", "'{'" )
    value_element_l()
    reconhecer( "}", "'}'" )
    local tab_eventtypescope = tab_curr_scope
    goto_father_scope()
    return tab_eventtypescope
  elseif tab_follow.rule_304[ token ] then
    return dclForward( name, TAB_TYPEID.EVENTTYPE )
  end --if
end

--[[function type_prefix_dcl()
  if tab_firsts.rule_260[ token ] then
    reconhecer( lex.tab_tokens.TK_TYPEPREFIX, "'typeprefix'" )
    scoped_name()
    reconhecer( lex.tab_tokens.TK_STRING_LITERAL, "<string literal>" )
  else
    sin_error( "'typeprefix'" )
  end --if
end
]]

--------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------

function parse( stridlparam, ptab_callbacks )
  if not ptab_callbacks then
    tab_callbacks = { }
  else
    tab_callbacks = ptab_callbacks
  end --if
  for type, tab in pairs( TAB_BASICTYPE ) do
    local callback = tab_callbacks[ type ]
    if callback then
      TAB_BASICTYPE[ type ] = callback
    end --if
  end --for
  tab_output       = { absolute_name = '' }
  tab_curr_scope   = tab_output
  tab_global_scope = tab_output
  tab_namespaces   = { 
                       [''] =   {
                                  tab_namespace = tab_output,
                                  curr_root = '',
                                  curr_scope = '',
                                  prefix = true
                                }
                     }
  tab_prefix_pragma_stack = { }
  label = nil
  table.insert( tab_prefix_pragma_stack, '' )
  tab_forward      = { }
  stridl = stridlparam
  oldPrefix = nil
  lex.init()
  token = get_token()
  specification()
  isForward()
  return tab_output
end
