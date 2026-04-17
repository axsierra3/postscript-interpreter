# PostScript Interpreter

A PostScript interpreter implemented in Ruby.

## Requirements

- Ruby 3.4.x or higher

## How to Run Interactive REPL
```
ruby interpreter.rb
```

This starts the interactive REPL where you can type PostScript commands line by line, a session may look like:
```
PostScript Interpreter -- type 'quit' to exit
REPL[0]> 3 5 add =
8
REPL[0]> /x 10 def
REPL[0]> x =
10
REPL[0]> quit
```
The number in brackets shows how many items are currently on the operand stack.

## Scoping Behavior

The interpreter uses **dynamic scoping by default**, as per the PostScript specification.

### Toggling Scoping Mode

Two built-in commands control scoping:

- `setlexical` — switches to lexical (static) scoping
- `setdynamic` — switches back to dynamic scoping

### Example demonstrating the difference

```postscript
/x 10 def
/getX { x } def
2 dict begin
    /x 99 def
    getX =       % dynamic: prints 99 (invoker's x)
                 % lexical: prints 10 (definer's x)
end
```
**Dynamic scoping** searches the dictionary stack from top to bottom at runtime —
variable lookup follows the invoker chain, so `getX` finds `x = 99` from the
calling scope.

**Lexical scoping** captures the environment at definition time — `getX` was defined
where `x = 10`, so it always resolves `x` to `10` regardless of the calling context.

## How to Run Testing Suite

```
ruby test_interpreter.rb
```

## Implemented Commands

| Category | Commands |
|---|---|
| Stack Manipulation | exch, pop, copy, dup, clear, count |
| Arithmetic | add, sub, mul, div, idiv, mod, abs, neg, ceiling, floor, round, sqrt |
| Dictionary | dict, length, maxlength, begin, end, def |
| Strings | length, get, getinterval, putinterval |
| Boolean/Bitwise | eq, ne, ge, gt, le, lt, and, or, not, true, false |
| Flow Control | if, ifelse, for, repeat, quit |
| Input/Output | print, =, == |


No commands from the required subset in Appendix A were left unimplemented.


## Architecture

The interpreter is structured around four core components:

- **`tokenize`** — breaks raw input into a list of tokens, handling code blocks
  `{ }` and strings `( )` as single tokens
- **`interpret`** — parses each token, identifies its type, and either pushes
  it onto the operand stack or passes it to `execute_command`
- **`execute_command`** — runs built-in PostScript commands using a `case/when`
  dispatch table
- **`lookup`** — searches the dictionary stack for user-defined variables and
  functions, supporting both dynamic and lexical scoping

Flow: The REPL takes an input line from stdin (the user), and passes it to tokenize, which passes it to interpret. Interpret handles it according to the token identified.


## Author

Ara Sierra — WSU CPTS 355





