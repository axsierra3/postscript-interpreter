
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
    $dict_stack.push({})    #push empty dictionary onto dict stack to avoid nil errors during tests
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

# -------STACK MANIPULATION TESTS-------
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

# -------ARITHMETIC TESTS-------
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