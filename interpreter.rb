require 'logger'

#LOGGER -- for debugging and tracing execution of our interpreter
# in here, set to DEBUG to see all msgs and ERROR to silence them
$logger = Logger.new(STDOUT)
$logger.level = Logger::DEBUG

#INTERPRETER CUSTOM EXCEPTIONS
# each exception is a class inheriting from StandardError
# wrote customs for more descriptive messages compared to generic Ruby
class TypeMismatch < StandardError      # wrong types passed to command, like add with string and int
    def initialize(message)  
            super(message)  
    end
end

class StackUnderflow < StandardError  # not enough operands on stack for a command (empty stack or too few tokens)
    def initialize(message)  
            super(message)  
    end
end

class ParseFailed < StandardError # token cant be parsed or found
    def initialize(message)  
            super(message)  
    end
end

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


#INTERPRET
# Takes a list of tokens from an input line and uses an if/elsif block to parse each token 
# (identify its type and meaning/role)
# Once identified/parsed, performs the appropriate action 
# If the token is a constanr (int, string, bool, code block, name constant) -- push it onto the operand stack
# If the token is a command (add, pop, def, etc.) -- pass it to execute_command to be run
def interpret(tokens)
    tokens.each do |token|

        #PARSE CODE BLOCK: push to operand stack
        # it will only be executed later when a command like if/repeat calls it
        if token.start_with?('{') 
            $op_stack.push(token) 

        #PARSE STRING: push to operand stack without the parentheses
        elsif token.start_with?('(')
            $op_stack.push(token[1..-2]) #strip off the parentheses and push just the string content

        #PARSE BOOLEAN: push to operand stack as Ruby boolean
        elsif token == 'true'
            $op_stack.push(true)
        elsif token == 'false'
            $op_stack.push(false)

        #PARSE INTEGER: push to operand stack as Ruby int
        elsif token =~ /^-?\d+$/  # regex to match an optional negative sign followed by digits
            $op_stack.push(token.to_i) # to_i converts string number to integer

        #PARSE FLOAT: push to operand stack as Ruby float
        elsif token =~ /^-?\d+\.\d+$/ # regex to match an optional negative sign, digits, a decimal point, and more digits
            $op_stack.push(token.to_f) # to_f converts string number to float

        #PARSE NAME CONSTANT: push to operand stack as string 
        # variable names like /x or /myvar 
        elsif token.start_with?('/')
            $op_stack.push(token)       #push and keep /

        #PARSE COMMAND OR VARIABLE LOOKUP --everything else
        # pass to execute_command
        else 
            execute_command(token)
        end       
    end   
end


#EXECUTE_COMMAND
# Called when a token us not a constant, it is either a command or variabke name
# first checks if token is a PostScript command ('when' branches) 
# if no command branch matches, it must be a variable name, call lookup() to find it in the dictionary stack (else block)
def execute_command(token)
    case token
        #------STACK MANIPULATION------
        when 'pop'
            # pops and discards the top value on the operand stack
            raise StackUnderflow, "pop: stack underflow" if $op_stack.empty?
            $op_stack.pop

        when 'dup'
            # duplicates the top value on the operand stack
            raise StackUnderflow, "dup: stack underflow" if $op_stack.empty?
            $op_stack.push($op_stack.last)

        when 'exch'
            #swaps the top two values on the operand stack
            raise StackUnderflow, "exch requires 2 operands: stack underflow" if $op_stack.size < 2
            a = $op_stack.pop
            b = $op_stack.pop
            $op_stack.push(a)
            $op_stack.push(b)

        when 'clear'
            # clears the operand stacck
            $op_stack.clear

        when 'count'
            # pushes count of items of stack, onto stack
            $op_stack.push($op_stack.length)


        #------ARITHMETIC------
        # Similar flow for add, sub, mul, div, idiv, mod
        # pop top 2 values, temporarily store in a and b, perform operation, push result back on stack
        when 'add'
            raise StackUnderflow, "add requires 2 operands: stack underflow" if $op_stack.size < 2
            b = $op_stack.pop 
            a = $op_stack.pop
            raise TypeMismatch, "add requires numeric operands: type mismatch" unless a.is_a?(Numeric) && b.is_a?(Numeric)
            $op_stack.push(a + b)

        when 'sub'
            raise StackUnderflow, "sub requires 2 operands: stack underflow" if $op_stack.size < 2
            b = $op_stack.pop 
            a = $op_stack.pop
            raise TypeMismatch, "sub requires numeric operands: type mismatch" unless a.is_a?(Numeric) && b.is_a?(Numeric)
            $op_stack.push(a - b)

        when 'mul'
            raise StackUnderflow, "mul requires 2 operands: stack underflow" if $op_stack.size < 2
            b = $op_stack.pop 
            a = $op_stack.pop
            raise TypeMismatch, "mul requires numeric operands: type mismatch" unless a.is_a?(Numeric) && b.is_a?(Numeric)
            $op_stack.push(a * b)

        when 'div'
            raise StackUnderflow, "div requires 2 operands: stack underflow" if $op_stack.size < 2
            b = $op_stack.pop 
            a = $op_stack.pop
            raise TypeMismatch, "div requires numeric operands: type mismatch" unless a.is_a?(Numeric) && b.is_a?(Numeric)
            $op_stack.push(a.to_f / b) # to_f ensures decimal division even for ints by forcing atleast one float

        when 'idiv'
            raise StackUnderflow, "idiv requires 2 operands: stack underflow" if $op_stack.size < 2
            b = $op_stack.pop 
            a = $op_stack.pop
            raise TypeMismatch, "idiv requires numeric operands: type mismatch" unless a.is_a?(Numeric) && b.is_a?(Numeric)
            $op_stack.push(a.to_i / b.to_i) #force both to be integers for automatic integer division

        when 'mod'
            raise StackUnderflow, "mod requires 2 operands: stack underflow" if $op_stack.size < 2
             b = $op_stack.pop 
             a = $op_stack.pop
             raise TypeMismatch, "mod requires numeric operands: type mismatch" unless a.is_a?(Numeric) && b.is_a?(Numeric)
            $op_stack.push(a % b) 

        when 'abs'
            raise StackUnderflow, "abs: stack underflow" if $op_stack.empty?
            raise TypeMismatch, "abs requires numeric operand: type mismatch" unless $op_stack.last.is_a?(Numeric)
            $op_stack.push($op_stack.pop.abs) #pop top value, take absolute value, push back on stack

        when 'neg'
            raise StackUnderflow, "neg: stack underflow" if $op_stack.empty?
            raise TypeMismatch, "neg requires numeric operand: type mismatch" unless $op_stack.last.is_a?(Numeric)
            $op_stack.push(-$op_stack.pop)  #pop top value, negate it, push back on stack

        when 'ceiling'
            raise StackUnderflow, "ceiling: stack underflow" if $op_stack.empty?
            raise TypeMismatch, "ceiling requires numeric operand: type mismatch" unless $op_stack.last.is_a?(Numeric)
            $op_stack.push($op_stack.pop.ceil) #pop top value, round up to nearest int, push back to stack

        when 'floor'
            raise StackUnderflow, "floor: stack underflow" if $op_stack.empty?
            raise TypeMismatch, "floor requires numeric operand: type mismatch" unless $op_stack.last.is_a?(Numeric)
            $op_stack.push($op_stack.pop.floor) #pop top value, round down, push back to stack
        
        when 'round'
            raise StackUnderflow, "round: stack underflow" if $op_stack.empty?
            raise TypeMismatch, "round requires numeric operand: type mismatch" unless $op_stack.last.is_a?(Numeric)
            $op_stack.push($op_stack.pop.round) #pop top value, round to nearest int, push back to stack
        
        when 'sqrt'
            raise StackUnderflow, "sqrt: stack underflow" if $op_stack.empty?
            raise TypeMismatch, "sqrt requires numeric operand: type mismatch" unless $op_stack.last.is_a?(Numeric)
            $op_stack.push(Math.sqrt($op_stack.pop)) #pop top value, calculate square root, push back to stack
        else 
            lookup(token) # if token doesnt mathc any built-in command, search the dictionary stack to push its value onto operand stack (if found)
    end
end


# LOOKUP
# Called by execute_command when a token isn't a built-in PostScript command
# Searches the dictionary stack from top to bottom for the variable name matching the token
# Dynamic scoping -- searches entire dict stack top to bottom for first match (invoker)
# Lexical/static scoping -- follows parent chain from current dict upward (definer)
# if found: either execute it (code block) or push its value onto operand stack (constant)
# if not found: raise ParseFailed because token is not valid constant, command, or variable name

def lookup(token)
    if $lexical_scope 
        #flag activated, follow parent chain
        current_dict = $dict_stack.last  #start with dictuonary at top of dict stack
        while current_dict != nil
            #if key name matches token
            if current_dict.key?(token) 
                value = current_dict[token]  #get the value assocaiated 
                #if vakue is a code block, take it apart and execute
                if value.is_a?(String) && value.start_with?('{')
                    interpret(tokenize(value[1..-2]))  #remove its curly brackets, tokenize it, and call interpret on each element token to execute
                else 
                    $op_stack.push(value) #otherwise push constant onto operand stack
                end
                return  #found it - stop searching
            end 
            current_dict = current_dict[:parent] #move pointer up to parent dict (:parent is a special symbol/key we use to link to the parent dictionary)
        end
    else 
        # dynamic scoping -- search dict stack from from top to bottom (searching invoker is same as following call chain at runtime)
        $dict_stack.reverse_each do |dict| 
            if dict.key?(token)
                value = dict[token]
                # if value is a code block, tokenize it and call interpret to execute it
                if value.is_a?(String) && value.start_with?('{')
                    interpret(tokenize(value[1..-2])) 
                else 
                    $op_stack.push(value) #push  value onto operand stack
                end  
                return  #found it - stop searching
            end  
        end
        #token wasnt found anywhere, parsing failed
        raise ParseFailed, "undefined token: '#{token}' not found in any dictionary"    
    end  
end


