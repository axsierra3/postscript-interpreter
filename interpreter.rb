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
$lexical_scope = false

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
# If the token is a constant (int, string, bool, code block, name constant) -- push it onto the operand stack
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
#------STACK MANIPULATION COOMMANDS------
        when 'pop'
            # pops and discards the top value on the operand stack
            raise StackUnderflow, "pop: stack underflow" if $op_stack.empty?
            $op_stack.pop

        when 'copy'
            #duplicates the top n elements of the op stack
            #leaves originals in place and pushes copies on top
            raise StackUnderflow, "copy: stack underflow" if $op_stack.empty?
            n = $op_stack.pop
            raise TypeMismatch, "copy requires an integer" unless n.is_a?(Integer)
            raise StackUnderflow, "copy: not enough elements in stack" if $op_stack.size < n
            # push(*) spreads them back onto stack as indv elements, not the array that was returned
            $op_stack.push(*$op_stack.last(n))
   

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


 #------ARITHMETIC COMMANDS------
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

#-------DICTIONARY COMMANDS------
        when 'dict'
            # creates a new empty dictionary and pushes it onto operand stack (hasnt been activated by begin yet, just sits on stack)
            # if lexical scoping is on: store the current top of dict stack as parent (it got defined here)
            new_dict = {}
            if $lexical_scope
                new_dict[:parent] = $dict_stack.last   #store parent pointer
            end
            $op_stack.push(new_dict)

        when 'begin'
            #pops dictionary from operand stack and pushes it onto the dictionary stack
            #this creates a new namespace/scope
            raise StackUnderflow, "begin: stack underflow" if $op_stack.empty?
            dict = $op_stack.pop
            raise TypeMismatch, "begin requires a dictionary" unless dict.is_a?(Hash)
            $dict_stack.push(dict)

        when 'end'
            # pops the top dictionary off the dict stack, discarding the current namespace/scope
            # never pop the last/global dictionary
            raise TypeMismatch, "end: cannot pop global dictionary from dictionary stack" if $dict_stack.size <= 1
            $dict_stack.pop

        when 'def'
            # pops a value and / name variable constant from operand stack
            # strips the / from the name and stores the key-value pair in the current dictionary on the dict stack
            raise StackUnderflow, "def requires 2 operands" if $op_stack.size < 2
            value = $op_stack.pop
            key = $op_stack.pop
            raise TypeMismatch, "def requires a name constant (starting with /)" unless key.is_a?(String) && key.start_with?('/')
            key = key[1..]  # strip the / off the front, so /x becomes x
            $dict_stack.last[key] = value 

        when 'length'
            # pushes total # of key-value pairs currently in dictionary
            # filter out :parent symbol key since its not a user defined entry
            raise StackUnderflow, "length: stack underflow" if $op_stack.empty?
            val = $op_stack.pop
            if val.is_a?(Hash)
                #filter out :parent key, since its an internal pointer
                $op_stack.push(val.count { |k, _| k != :parent })   
            elsif val.is_a?(String)
                $op_stack.push(val.length)    #length for strings
            else
                raise TypeMismatch, "length requies a dictionary or string"           
            end
                  
        when 'maxlength'
            # in real PostScript dictionaries have a fixed capacity
            # Ruby hashes are dynamic so we just return the current length
            raise StackUnderflow, "maxlength: stack underflow" if $op_stack.empty?
            dict = $op_stack.pop
            raise TypeMismatch, "maxlength requires a dictionary" unless dict.is_a?(Hash)
            $op_stack.push(dict.count { |k, _| k != :parent })

#--------STRING COMMANDS------
        # pops a string and a number (index), pushes the ASCII code of the character found at that index
        # ex: (hello) 0 get =    , returns 101 (ASCII for 'h') 
        when 'get' 
            raise StackUnderflow, "get requires 2 operands" if $op_stack.size < 2
            index = $op_stack.pop
            str = $op_stack.pop
            raise TypeMismatch, "get requires a string and an integer" unless str.is_a?(String) && index.is_a?(Integer)
            raise TypeMismatch, "get: index out of bounds" if index < 0 || index >= str.length
            $op_stack.push(str[index].ord) # .ord converts character to ASCII code
        
        #pops a string, start index and count -- returns substing from start to amt of chars 
        #ex: (hello) 1 3 getinterval returns ell
        when 'getinterval'
            raise StackUnderflow, "getinterval requires 3 operands" if $op_stack.size < 3
            count = $op_stack.pop
            start = $op_stack.pop
            str = $op_stack.pop
            raise TypeMismatch, "getinterval requires string, integer, integer" unless str.is_a?(String) && start.is_a?(Integer) && count.is_a?(Integer)
            raise TypeMismatch, "getinterval: index out of bounds" if start < 0 || start + count > str.length
            $op_stack.push(str[start, count])  # str[start, count] is Ruby's substring syntax

        # pops string1, index, string2 -- replaces part of string 1 by replacing from index onwards
        # ex: (hellow word) 6 (Ruby!) putinterval = hello Ruby! 
        when 'putinterval'
            raise StackUnderflow, "putinterval requires 3 operands" if $op_stack.size < 3
            str2 = $op_stack.pop
            index = $op_stack.pop
            str1 = $op_stack.pop
            raise TypeMismatch, "putinterval requires string, integer, string" unless str1.is_a?(String) && index.is_a?(Integer) && str2.is_a?(String)
            raise TypeMismatch, "putinterval: index out of bounds" if index < 0 || index + str2.length > str1.length
            str1[index, str2.length] = str2  # Ruby string slice assignment
            $op_stack.push(str1)
   

 #------BOOLEAN COMMANDS------
        when 'eq'
            # tests equal
            raise StackUnderflow, "eq requires 2 operands: stack underflow" if $op_stack.size < 2
            b = $op_stack.pop
            a = $op_stack.pop
            #check same type AND same value
            $op_stack.push(a.class == b.class && a == b) #push true if a and b are equal, false otherwise

        when 'ne'
            # tests not equal
            raise StackUnderflow, "ne requires 2 operands: stack underflow" if $op_stack.size < 2
            b = $op_stack.pop
            a = $op_stack.pop
            $op_stack.push(a.class == b.class && a != b) #push true if a and b are not equal, false otherwise

        when 'gt'
            # tests greater than
            raise StackUnderflow, "gt requires 2 operands: stack underflow" if $op_stack.size < 2
            b = $op_stack.pop
            a = $op_stack.pop
            raise TypeMismatch, "gt requires numeric or string operands: type mismatch" unless (a.is_a?(Numeric) && b.is_a?(Numeric)) || (a.is_a?(String) && b.is_a?(String))
            $op_stack.push(a > b) #push true if a is greater than b, false otherwise

        when 'ge'
            # tests greater than or equal
            raise StackUnderflow, "ge requires 2 operands: stack underflow" if $op_stack.size < 2
            b = $op_stack.pop   
            a = $op_stack.pop
            raise TypeMismatch, "ge requires numeric or string operands: type mismatch" unless (a.is_a?(Numeric) && b.is_a?(Numeric)) || (a.is_a?(String) && b.is_a?(String))
            $op_stack.push(a >= b) #push true if a is greater than or equal to b, false otherwise   

        when 'lt'
            # tests less than
            raise StackUnderflow, "lt requires 2 operands: stack underflow" if $op_stack.size < 2
            b = $op_stack.pop
            a = $op_stack.pop
            raise TypeMismatch, "lt requires numeric or string operands: type mismatch" unless (a.is_a?(Numeric) && b.is_a?(Numeric)) || (a.is_a?(String) && b.is_a?(String))
            $op_stack.push(a < b) #push true if a is less than b, false otherwise

        when 'le'
            # tests less than or equal
            raise StackUnderflow, "le requires 2 operands: stack underflow" if $op_stack.size < 2
            b = $op_stack.pop
            a = $op_stack.pop
            raise TypeMismatch, "le requires numeric or string operands: type mismatch" unless (a.is_a?(Numeric) && b.is_a?(Numeric)) || (a.is_a?(String) && b.is_a?(String))
            $op_stack.push(a <= b) #push true if a is less than or equal to b, false otherwise

        when 'and'
            # tests logical or bitwise AND
            # for bools, push true if both operands are true, false otherwise
            # for ints, push bitwise AND result
            raise StackUnderflow, "and requires 2 operands: stack underflow" if $op_stack.size < 2
            b = $op_stack.pop
            a = $op_stack.pop
            if (a == true || a == false) && (b == true || b == false)
                $op_stack.push(a && b) #logical AND for bools
            elsif a.is_a?(Integer) && b.is_a?(Integer)
                $op_stack.push(a & b) #bitwise AND for ints (compares if both bits are 1)
            else 
                raise TypeMismatch, "and requires both operands to be bools or ints: type mismatch"  
            end

        when 'or'
            # tests logical or bitwise OR
            # for bools, push true if at least one operand is true, false otherwise
            # for ints, push bitwise OR result
            raise StackUnderflow, "or requires 2 operands: stack underflow" if $op_stack.size < 2
            b = $op_stack.pop
            a = $op_stack.pop
            if (a == true || a == false) && (b == true || b == false)
                $op_stack.push(a || b) #logical OR for bools
            elsif a.is_a?(Integer) && b.is_a?(Integer)
                $op_stack.push(a | b) #bitwise OR for ints (compares if at least one bit is 1)
            else 
                raise TypeMismatch, "or requires both operands to be bools or ints: type mismatch"    
            end

        when 'not'
            # logical or bitwise NOT
            # for bools, negate (push true if operand is false, false if operand is true)
            # for ints, push bitwise NOT result (invert each binary num)
            raise StackUnderflow, "not requires 1 operand: stack underflow" if $op_stack.empty?
            val = $op_stack.pop
            if val == true || val == false
                $op_stack.push(!val) #logical NOT for bools
            elsif val.is_a?(Integer)
                $op_stack.push(~val) #bitwise NOT for ints (invert each bit)
            else 
                raise TypeMismatch, "not requires operand to be a bool or int: type mismatch"      
            end

        when 'true' 
            #pushes boolean true onto operand stack
            $op_stack.push(true)

        when 'false'
            #pushes boolean false onto operand stack
            $op_stack.push(false)


#------FLOW CONTROL COMMANDS-------
        # pops a boolean and a code block
        # executes the code block only if boolean is true
        when 'if' 
            raise StackUnderflow, "if requires 2 operands" if $op_stack.size < 2
            block = $op_stack.pop
            condition = $op_stack.pop
            raise TypeMismatch, "if requires a boolean" unless condition == true || condition == false
            raise TypeMismatch, "if requires a code block" unless block.is_a?(String) && block.start_with?('{')
            if condition
                interpret(tokenize(block[1..-2])) #strip {}, tokenize, interpret code block if true
            end

        # pops a boolean and TWO code blocks
        # executes first block if true, second block if false
        when 'ifelse'
            raise StackUnderflow, "ifelse requires 3 operands" if $op_stack.size < 3
            false_block = $op_stack.pop   # second block -- executed if false
            true_block = $op_stack.pop    # first block -- executed if true
            condition = $op_stack.pop
            raise TypeMismatch, "ifelse requires a boolean" unless condition == true || condition == false
            raise TypeMismatch, "ifelse requires code blocks" unless true_block.is_a?(String) && true_block.start_with?('{')
            if condition
                interpret(tokenize(true_block[1..-2]))
            else
                interpret(tokenize(false_block[1..-2]))
            end

        #pops a number n and a code block
        # repepats the code block n times
        when 'repeat'
            raise StackUnderflow, "repeat requires 2 operands" if $op_stack.size < 2
            block = $op_stack.pop
            n = $op_stack.pop
            raise TypeMismatch, "repeat requires an integer" unless n.is_a?(Integer)
            raise TypeMismatch, "repeat requires a code block" unless block.is_a?(String) && block.start_with?('{')
            n.times do
            interpret(tokenize(block[1..-2]))   #keep re executing same block n times
            end

        # pops initial (where to start counter), step (increment/decrement), limit (when to stop), and a code block
        # executes code block initial to limit amt of timees, incrementing by step
        # the counter gets pushed to stack before each iteration to be used in block
        # EX: 0 1 3 { = } for, i starts at 0, goes up by 1, stops when i >= 3, would print 0 1 2 3 since the code block is just =
        when 'for' 
            raise StackUnderflow, "for requires 4 operands" if $op_stack.size < 4
            block = $op_stack.pop
            limit = $op_stack.pop
            step = $op_stack.pop
            initial = $op_stack.pop
            raise TypeMismatch, "for requires numeric arguments" unless initial.is_a?(Numeric) && step.is_a?(Numeric) && limit.is_a?(Numeric)
            raise TypeMismatch, "for requires a code block" unless block.is_a?(String) && block.start_with?('{')
            i = initial
            while (step > 0 && i <= limit) || (step < 0 && i >= limit) #for pos and neg steps
                $op_stack.push(i)
                interpret(tokenize(block[1..-2]))
                i += step       
            end

        #exit the REPL program/interpreter and go to terminal
        when 'quit'
            exit


#------OUTPUT COMMANDS------
        when 'print'  
            #pops top val and prints to stdout w/out newline
            raise StackUnderflow, "print: stack underflow" if $op_stack.empty?
            print $op_stack.pop
        
        when '='
            # pops top val and pritns it with a newline (thats the difference betw print and = in PostScript)
            raise StackUnderflow, "= : stack underflow" if $op_stack.empty?
            puts $op_stack.pop

        when '=='
            # pops and returns PostScript representation of top of stack ()
            raise StackUnderflow, "== : stack underflow" if $op_stack.empty?
            val = $op_stack.pop
            if val.is_a?(String)
                puts "(#{val})"  #stringsx print w/ parentheses in PostScript
            else 
                puts val    # everything else prints normally
            end

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

# REPL
# Read-Eval-Print Loop
# Reads a line of input typed by user, tokenizes it, interpets and evaluates it, and loops back
# An interactive interface to connect user to interact with the interpreter
# Reads the code and instructs the interpreter to evaluate it 
# Rescues exceptions so a faulty input doesnt crash the whole interpreter
def repl
    puts "PostScript Interpreter -- type 'quit' to exit"  
    while true
        begin
            print "REPL[#{$op_stack.size}]> "                   #print prompt (with amt of items in stack)
            input = gets.chomp                                  # read line of input, strip newline
            next if input.empty?                                # skip empty lines of input (they just hit newline)
            tokens = tokenize(input)                            # make an array of separated tokens from that line
            interpret(tokens)                                   # pass each token to interpret to decide what action/execution to do with each 
        rescue StackUnderflow, TypeMismatch, ParseFailed => e   #rescue catches the exception and puts it as an object e so we have message e
            puts "Error: #{e.message}"
        end
    end     
end

# only run the REPL if this file is being run directly
if __FILE__ == $0   #FILE returns the name of this file and $0 is the name of the file that was run directly in the terminal 
    repl            #so when you run ruby interpreter.rb both equal interpreter.rb, so run REPL
end


