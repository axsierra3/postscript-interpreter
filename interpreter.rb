require 'logger'

#LOGGER -- for debugging and tracing execution of our interpreter
# in here, set to DEBUG to see all msgs and ERROR to silence them
$logger = Logger.new(STDOUT)
$logger.level = Logger::DEBUG

#2 GLOBAL STACKS
# Operand stack--
# Holds values being pushed and popped by PostScript commands during execution
# Constands (ints, srings, bools, arrays, var names, code blocks) are pushed here
# commands like add, mul, def, if, etc. pop values from this to perform their operations
$op_stack = []

# Dictionary stack-- stack of dictionaries (hashes) 
# Used to hold the current name-value bindings for variable loookup 
# Each dictionary in the stack represents a scope, and the topmost dictionary is the current scope
# When a new variable/funct is defined, it is added to the current dictionary
# When looking up a variable, the interpreter searches from the top of the stack downwards until it finds the variable or reaches the bottom of the stack
$dict_stack = [{}]

#FLAG: dynamic by default, can be set to true for lexccal/static scoping
$lexcial_scope = false

#TODO: set up REPL loop to read lines of input, tokenize, and execute commands

#TOKENIZER
# Takes a string of PostScript code and breaks it into a list of indv tokens
# Handles 3 cases: 
# 1. Curly braces { } --- code blocls, kept as a single token
# 2. Parentheses ( ) --- strings in PostScript
# 3. Regular tokens -- split by whitespace

def tokenize(input)
    tokens = []         #this will hold our final list of tokens  
    i = 0               # i is our postion in the input string

    while i < input.length

    #skip whitespace
        if input[i]  =~ /\s/    # ~= is the pattern/regex match operator
            i += 1                # if the current character is whitespace, just move forward in input and restart loop
            next
        end

      #handle code blocks -- everything between { and }
      # must keep track of depth (nested code blocks) such as { { 3 4 add } dup mul }
        if input[i] == '{'
            depth = 1               # we just opened one brace
            j = i + 1               # j scans ahead to find the matching closing brace
            while j < input.length && depth > 0 
                depth += 1 if input[j] == '{' #found another opening brace
                depth -= 1 if input[j] == '}' #found closing brace, if a;; matched depth will be 0
                j += 1
            end
            # grab the whole code block inluding { and } as one token 
            tokens << input[i...j]   #add to our token list
            i = j                    # move i to the position after the closing brace
        
            # handle strings -- everything between ( and )
        elsif input[i] == '('
            j = i + 1            # j scans ahead to find the matching closing parenthesis
            while j < input.length && input[j] != ')'
                j += 1  
            end
            # grab whole string including ( and ) as one token, add to tokens list
            tokens << input[i..j] 
            i = j + 1            # move i to the position after the closing parenthesis

        #handle everything else -- scan until whitespace or special characters AKA { } ( )
        else 
            j = i
            while j < input.length && input[j] !~ /[\s{}()]/
              j += 1
            end

            # add the token to our list
            tokens << input[i...j]
            i = j                   #move i to special char or whitespace spot
        end
    end

    tokens #returns the list of tokens for this input string line
end


#EXECUTOR
# Takes a list of tokens from an input line and uses an if/elsif block to parse each token 
# (identify its type and meaning/role)
# Once identified/parsed, performs the appropriate action 
# If the token is a constanr (int, string, bool, code block, name constant) -- push it onto the operand stack
# If the token is a command (add, pop, def, etc.) -- pass it to execute_command to be run
def execute(tokens)

      
end

