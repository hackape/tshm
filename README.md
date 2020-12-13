# tshm

A WIP parser for TypeScript declarations that seeks to output HM-style type signatures.

Example usage:

```
$ tshm "export declare const f: <A>(a: A) => (b: string) => A"
f :: A -> string -> A
```

Should an invalid input be provided the program will fail with the appropriate exit code, enabling the use of tshm in shell pipelines.

Messages are always printed upon failure. Should the failure be due to a parser error, the raw error is printed to the console to assist in debugging.

## What's not yet supported?

This is not an exhaustive list!

### Input

- Syntactic parentheses e.g. `(() => void)[]`
- Nested special array syntax e.g. `string[][]`
- Object literal keys that aren't ordinary static strings
- Object type references e.g. `MyType['myProp']`
- `extends` clauses
- Irregular spacing
- Newlines
- Semicolons

### Output

- HM-style higher-kinded types output e.g. `Option<string>` -> `Option string`
- Dedicated array syntax e.g. `string[]` or `Array<string>` -> `[string]`
- Lowercase single-char type arguments e.g. `A -> B` -> `a -> b`

