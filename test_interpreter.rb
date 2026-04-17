
#ruby's built-in testing library, minitest
#each class inherits from Minitest
#to run tests, just run this file with `ruby test_interpreter.rb`
require 'minitest/autorun'
#import our interpreter file to test
require_relative 'interpreter'

# ----------TOKENIZER TESTS------------
class TestTokenizer < Minitest::Test
    
    def test_tokenize_add
        #simple test to split nmumbers and command
        assert_equal ["3", "4", "add"], tokenize("3 4 add") #assert_equal format: expected output, input
    end

    def test_whitespace
            #extra whitespace between tokens should be ignored
            assert_equal ["3", "4"], tokenize("  3      4  ")  
    end

    def test_tokenize_code_block
        #everything between { } should be ONE token
        assert_equal ["{3 4 add}", "dup", "mul"], tokenize("{3 4 add} dup mul")
    end

    def test_tokenize_string
        # everything between ( ) should be ONE token
        assert_equal ["(hello)"], tokenize("(hello)")
    end

    def test_tokenize_nested_code_block
        # nested braces should still be one token
        assert_equal ["{{3} 5}"], tokenize("{{3} 5}")
    end
end

# helper method to reset stacks before each test
# so tests dont interfere with each other
def reset
    $op_stack.clear         #clear operand stack
    $dict_stack.clear       #clear dictionary stack
    $dict_stack.push({})    #push 'global' dictionary onto stack
end

# ----------INTERPRET/PARSE TESTS------------
class TestInterpreter < Minitest::Test
    def setup
        reset  # Minitest looks for and runs before every single test method in this class to clear the stack
    end

    def test_push_integer
        interpret(["3"])
        assert_equal [3], $op_stack
    end

    def test_push_float
        interpret(["3.14"])
        assert_equal [3.14], $op_stack
    end

    def test_push_boolean_true
        interpret(["true"])
        assert_equal [true], $op_stack
    end

    def test_push_boolean_false
        interpret(["false"])
        assert_equal [false], $op_stack
    end

    def test_push_string
        interpret(["(hello)"])
        assert_equal ["hello"], $op_stack
    end

    def test_push_code_block
        interpret(["{3 5 add}"])
        assert_equal ["{3 5 add}"], $op_stack
    end

    def test_push_name_constant
        interpret(["/x"])
        assert_equal ["/x"], $op_stack
    end

end

# -------STACK MANIPULATION COMMAND TESTS-------
class TestStackCommands < Minitest::Test

    def setup
        reset
    end

    def test_pop
        $op_stack.push(3)
        execute_command('pop')
        assert_equal [], $op_stack
    end

    def test_pop_underflow
        assert_raises(StackUnderflow) { execute_command('pop') }
    end

    def test_dup
        $op_stack.push(5)
        execute_command('dup')
        assert_equal [5, 5], $op_stack
    end

    def test_dup_underflow
        assert_raises(StackUnderflow) { execute_command('dup') }
    end

    def test_exch
        $op_stack.push(1)
        $op_stack.push(2)
        execute_command('exch')
        assert_equal [2, 1], $op_stack
    end

    def test_exch_underflow
        $op_stack.push(1)
        assert_raises(StackUnderflow) { execute_command('exch') }
    end

    def test_clear
        $op_stack.push(1)
        $op_stack.push(2)
        $op_stack.push(3)
        execute_command('clear')
        assert_equal [], $op_stack
    end

    def test_count
        $op_stack.push(1)
        $op_stack.push(2)
        $op_stack.push(3)
        execute_command('count')
        assert_equal [1, 2, 3, 3], $op_stack
    end

end

# -------ARITHMETIC COMMAND TESTS-------
class TestArithmetic < Minitest::Test

    def setup
        reset
    end

    def test_add
        $op_stack.push(3)
        $op_stack.push(5)
        execute_command('add')
        assert_equal [8], $op_stack
    end

    def test_add_underflow
        $op_stack.push(3)
        assert_raises(StackUnderflow) { execute_command('add') }
    end

    def test_add_type_mismatch
        $op_stack.push("hello")
        $op_stack.push(3)
        assert_raises(TypeMismatch) { execute_command('add') }
    end

    def test_sub
        $op_stack.push(10)
        $op_stack.push(3)
        execute_command('sub')
        assert_equal [7], $op_stack
    end

    def test_mul
        $op_stack.push(4)
        $op_stack.push(3)
        execute_command('mul')
        assert_equal [12], $op_stack
    end

    def test_div
        $op_stack.push(7)
        $op_stack.push(2)
        execute_command('div')
        assert_equal [3.5], $op_stack
    end

    def test_idiv
        $op_stack.push(7)
        $op_stack.push(2)
        execute_command('idiv')
        assert_equal [3], $op_stack
    end

    def test_mod
        $op_stack.push(7)
        $op_stack.push(3)
        execute_command('mod')
        assert_equal [1], $op_stack
    end

    def test_abs_positive
        $op_stack.push(-5)
        execute_command('abs')
        assert_equal [5], $op_stack
    end

    def test_abs_negative
        $op_stack.push(5)
        execute_command('abs')
        assert_equal [5], $op_stack
    end

    def test_neg
        $op_stack.push(5)
        execute_command('neg')
        assert_equal [-5], $op_stack
    end

    def test_ceiling
        $op_stack.push(3.2)
        execute_command('ceiling')
        assert_equal [4], $op_stack
    end

    def test_floor
        $op_stack.push(3.8)
        execute_command('floor')
        assert_equal [3], $op_stack
    end

    def test_round
        $op_stack.push(3.5)
        execute_command('round')
        assert_equal [4], $op_stack
    end

    def test_sqrt
        $op_stack.push(9)
        execute_command('sqrt')
        assert_equal [3.0], $op_stack
    end

end


# -------DICTIONARY AND DICTIONARY LOOKUP TESTS-------
class TestDictionary < Minitest::Test

    def setup
        reset
    end
#Dictionary Commands
    #checks if dict will push an empty dict {} onto op stack '3 dict'
    def test_dict_creates_hash
        $op_stack.push(2)
        execute_command('dict')
        assert_equal true, $op_stack.last.is_a?(Hash)
    end

    #checks if begin will push empty dict {} from op stack to dict stack '3 dict begin'
    def test_begin_pushes_to_dict_stack
        $op_stack.push({})
        execute_command('begin')
        assert_equal 2, $dict_stack.size
    end

    #checks if end pops existing dict from dict stack
    def test_end_pops_dict_stack
        $op_stack.push({})
        execute_command('begin')
        execute_command('end')
        assert_equal 1, $dict_stack.size
    end

    #assure global dictionary cant be popped (exception)
    def test_end_cannot_pop_global
        assert_raises(TypeMismatch) { execute_command('end') }
    end

    #test def takes two constants from stack successfuly stores as key-val pair in latest dictionary (no /)
    def test_def_stores_variable
        $op_stack.push("/x")
        $op_stack.push(5)
        execute_command('def')
        assert_equal 5, $dict_stack.last["x"]
    end

    #checks def requires / for var names
    def test_def_requires_name_constant
        $op_stack.push("x")   # no / prefix
        $op_stack.push(5)
        assert_raises(TypeMismatch) { execute_command('def') }
    end
     
    #lookup test: checks if when a variable name is executed, it is looked for in top dictionary and its value is pushed to op stack
    def test_lookup_variable
        $dict_stack.last["x"] = 42
        execute_command('x')
        assert_equal [42], $op_stack
    end

    #checks if undefined variable raises ParseFailed exception
    def test_lookup_undefined
        assert_raises(ParseFailed) { execute_command('z') }
    end

#checks if length pushes dict length correctly
    def test_length_dict
    #pushes a dictionary with two key-val pairs onto operand stack
    $op_stack.push({"x" => 1, "y" => 2})

    #length pops that dictionary off and pushes length onto op stackm as a number
       execute_command('length')
       assert_equal [2], $op_stack
    end

#string length test
    def test_length_string
        $op_stack.push("hello")
        execute_command('length')
        assert_equal [5], $op_stack
    end
end

# -------STRING TESTS-------
class TestStrings < Minitest::Test

    def setup
        reset
    end

    def test_get_returns_ascii
        $op_stack.push("hello")
        $op_stack.push(0)
        execute_command('get')
        assert_equal [104], $op_stack  # ASCII for 'h'
    end

    def test_get_middle_char
        $op_stack.push("hello")
        $op_stack.push(1)
        execute_command('get')
        assert_equal [101], $op_stack  # ASCII for 'e'
    end

    def test_get_out_of_bounds
        $op_stack.push("hello")
        $op_stack.push(10)
        assert_raises(TypeMismatch) { execute_command('get') }
    end

    def test_getinterval
        $op_stack.push("hello")
        $op_stack.push(1)
        $op_stack.push(3)
        execute_command('getinterval')
        assert_equal ["ell"], $op_stack
    end

    def test_getinterval_from_start
        $op_stack.push("hello world")
        $op_stack.push(6)
        $op_stack.push(5)
        execute_command('getinterval')
        assert_equal ["world"], $op_stack
    end

    def test_putinterval
        $op_stack.push("hello")
        $op_stack.push(0)
        $op_stack.push("HE")
        execute_command('putinterval')
        assert_equal ["HEllo"], $op_stack
    end

    def test_putinterval_middle
        $op_stack.push("hello world")
        $op_stack.push(6)
        $op_stack.push("Ruby!")
        execute_command('putinterval')
        assert_equal ["hello Ruby!"], $op_stack
    end

    def test_length_string
        $op_stack.push("hello")
        execute_command('length')
        assert_equal [5], $op_stack
    end

end

# -------BOOLEAN/COMPARISON TESTS-------
class TestBooleans < Minitest::Test

    def setup
        reset
    end

    def test_eq_true
        $op_stack.push(5)
        $op_stack.push(5)
        execute_command('eq')
        assert_equal [true], $op_stack
    end

    def test_eq_false
        $op_stack.push(3)
        $op_stack.push(5)
        execute_command('eq')
        assert_equal [false], $op_stack
    end

    def test_eq_strings
        $op_stack.push("hello")
        $op_stack.push("hello")
        execute_command('eq')
        assert_equal [true], $op_stack
    end

    def test_ne
        $op_stack.push(3)
        $op_stack.push(5)
        execute_command('ne')
        assert_equal [true], $op_stack
    end

    def test_gt_true
        $op_stack.push(10)
        $op_stack.push(3)
        execute_command('gt')
        assert_equal [true], $op_stack
    end

    def test_gt_false
        $op_stack.push(3)
        $op_stack.push(10)
        execute_command('gt')
        assert_equal [false], $op_stack
    end

    def test_lt_true
        $op_stack.push(3)
        $op_stack.push(10)
        execute_command('lt')
        assert_equal [true], $op_stack
    end

    def test_ge
        $op_stack.push(5)
        $op_stack.push(5)
        execute_command('ge')
        assert_equal [true], $op_stack
    end

    def test_le
        $op_stack.push(3)
        $op_stack.push(5)
        execute_command('le')
        assert_equal [true], $op_stack
    end

    def test_and_booleans
        $op_stack.push(true)
        $op_stack.push(false)
        execute_command('and')
        assert_equal [false], $op_stack
    end

    def test_and_integers
        $op_stack.push(5)
        $op_stack.push(3)
        execute_command('and')
        assert_equal [1], $op_stack  # 5 & 3 = 001 in bits so 1 as a number
    end

    def test_or_booleans
        $op_stack.push(true)
        $op_stack.push(false)
        execute_command('or')
        assert_equal [true], $op_stack
    end

    def test_not_boolean
        $op_stack.push(true)
        execute_command('not')
        assert_equal [false], $op_stack
    end

    def test_gt_type_mismatch
        $op_stack.push("hello")
        $op_stack.push(3)
        assert_raises(TypeMismatch) { execute_command('gt') }
    end

    def test_and_type_mismatch
        $op_stack.push(true)
        $op_stack.push(3)
        assert_raises(TypeMismatch) { execute_command('and') }
    end

end

# -------FLOW CONTROL TESTS-------
class TestFlowControl < Minitest::Test

    def setup
        reset
    end

    def test_if_true
        $op_stack.push(true)
        $op_stack.push("{1 2 add}")
        execute_command('if')
        assert_equal [3], $op_stack
    end

    def test_if_false
        # block should NOT execute when condition is false
        $op_stack.push(false)
        $op_stack.push("{1 2 add}")
        execute_command('if')
        assert_equal [], $op_stack  # nothing pushed, block never ran
    end

    def test_if_requires_boolean
        $op_stack.push(3)   # not a boolean
        $op_stack.push("{1 2 add}")
        assert_raises(TypeMismatch) { execute_command('if') }
    end

    def test_ifelse_true_branch
        $op_stack.push(true)
        $op_stack.push("{10}")   # true block
        $op_stack.push("{20}")   # false block
        execute_command('ifelse')
        assert_equal [10], $op_stack
    end

    def test_ifelse_false_branch
        $op_stack.push(false)
        $op_stack.push("{10}")   # true block
        $op_stack.push("{20}")   # false block
        execute_command('ifelse')
        assert_equal [20], $op_stack
    end

    def test_repeat
        $op_stack.push(3)
        $op_stack.push("{1}")   # pushes 1 three times
        execute_command('repeat')
        assert_equal [1, 1, 1], $op_stack
    end

    def test_repeat_zero_times
        $op_stack.push(0)
        $op_stack.push("{1}")
        execute_command('repeat')
        assert_equal [], $op_stack  # block never ran
    end

    def test_for_count_up
        # 0 1 3 { } for should push 0, 1, 2, 3 onto stack
        $op_stack.push(0)   # initial
        $op_stack.push(1)   # step
        $op_stack.push(3)   # limit
        $op_stack.push("{}")  # empty block, just pushes counter
        execute_command('for')
        assert_equal [0, 1, 2, 3], $op_stack
    end

    def test_for_count_by_two
        $op_stack.push(0)   # initial
        $op_stack.push(2)   # step
        $op_stack.push(6)   # limit
        $op_stack.push("{}")
        execute_command('for')
        assert_equal [0, 2, 4, 6], $op_stack
    end

    def test_for_count_down
        $op_stack.push(3)    # initial
        $op_stack.push(-1)   # step
        $op_stack.push(0)    # limit
        $op_stack.push("{}")
        execute_command('for')
        assert_equal [3, 2, 1, 0], $op_stack
    end

    def test_for_with_operation
        # 1 1 3 { dup mul } for should push squares: 1, 4, 9
        $op_stack.push(1)
        $op_stack.push(1)
        $op_stack.push(3)
        $op_stack.push("{dup mul}")
        execute_command('for')
        assert_equal [1, 4, 9], $op_stack
    end

end


# -------OUTPUT TESTS-------
class TestOutput < Minitest::Test

  def setup
        reset
  end

    def test_print
        $op_stack.push("hello")
        # assert_output checks what gets printed to stdout
        assert_output("hello") { execute_command('print') }
        assert_equal [], $op_stack  # stack should be empty after
    end

    def test_equals
        $op_stack.push(42)
        assert_output("42\n") { execute_command('=') }
        assert_equal [], $op_stack
    end

    def test_double_equals_string
        $op_stack.push("hello")
        assert_output("(hello)\n") { execute_command('==') } #returns post script version of top of stack
        assert_equal [], $op_stack
    end

    def test_double_equals_number
        $op_stack.push(42)
        assert_output("42\n") { execute_command('==') }
        assert_equal [], $op_stack
    end

    def test_print_underflow
        assert_raises(StackUnderflow) { execute_command('print') }
    end
end


