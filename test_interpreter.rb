
#ruby's built-in testing library, minitest
require 'minitest/autorun'
#import our interpreter file to test
require_relative 'interpreter'

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