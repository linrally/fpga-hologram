# Assembly Program Notes

## Assembling cube_pov.s

The assembly file `src/cube_pov.s` needs to be assembled into a memory initialization file `src/cube_prog.mem` that can be loaded by the ROM module.

### Expected Output Format

The `.mem` file should contain hexadecimal values, one per line, representing 32-bit instructions:

```
00000000
00000001
00000002
...
```

This format is compatible with Verilog's `$readmemh()` function used in `ROM.v`.

### Instruction Encoding

Based on `processor.v`, the instruction format is:

**R-type (opcode = 00000):**
```
[31:27] = 00000 (opcode)
[26:22] = rd (destination register)
[21:17] = rs (source register 1)
[16:12] = rt (source register 2)
[11:7]  = shamt (shift amount)
[6:2]   = aluop (ALU operation)
[1:0]   = unused
```

**I-type:**
```
[31:27] = opcode
[26:22] = rd (destination register)
[21:17] = rs (source register)
[16:0]  = immediate (17-bit, sign-extended)
```

**J-type:**
```
[31:27] = opcode
[26:0]  = T (target address or immediate)
```

### Opcodes

- `00000`: R-type
- `00101`: addi
- `01000`: lw
- `00111`: sw
- `00010`: bne
- `00110`: blt
- `00001`: j
- `00011`: jal
- `00100`: jr
- `10101`: setx
- `10110`: bex

### ALU Operations (for R-type)

- `00000`: add
- `00001`: sub
- `00010`: and
- `00011`: or
- `00110`: mult
- `00111`: div
- (sll and sra use shamt field)

### Example Assembly to Machine Code

The assembler should convert instructions like:
```
addi $1, $0, 0xFFFF
```

Into the appropriate 32-bit machine code based on the instruction format above.

### Notes

- The assembly program uses standard MIPS-like syntax, but the actual instruction encoding may differ
- Register numbers: `$0` through `$31` (5 bits)
- Immediate values are 17-bit sign-extended
- Branch targets use PC-relative addressing (PC - 1 + immediate)

### Testing the Assembly

After assembling, verify:
1. The `.mem` file contains valid hexadecimal values
2. The file is readable by `$readmemh()`
3. The CPU executes the program correctly (use simulation or debug tools)

