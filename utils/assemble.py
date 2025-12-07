#!/usr/bin/env python3
"""
Assembler for the custom CPU instruction set
Converts assembly files (.s) to memory files (.mem) for ROM initialization
"""

import re
import sys

# Opcodes
OPCODE_R_TYPE = 0b00000
OPCODE_ADDI   = 0b00101
OPCODE_LW     = 0b01000
OPCODE_SW     = 0b00111
OPCODE_BNE    = 0b00010
OPCODE_BLT    = 0b00110
OPCODE_J      = 0b00001
OPCODE_JAL    = 0b00011
OPCODE_JR     = 0b00100
OPCODE_SETX   = 0b10101
OPCODE_BEX    = 0b10110

# ALU operations (for R-type)
ALUOP_ADD = 0b00000
ALUOP_SUB = 0b00001
ALUOP_AND = 0b00010
ALUOP_OR  = 0b00011
ALUOP_MULT = 0b00110
ALUOP_DIV  = 0b00111
# sll and sra use shamt field directly

def parse_register(reg_str):
    """Parse register string like '$1' or '$0' and return register number"""
    match = re.match(r'\$(\d+)', reg_str.strip())
    if match:
        reg_num = int(match.group(1))
        if reg_num < 0 or reg_num > 31:
            raise ValueError(f"Invalid register number: {reg_num}")
        return reg_num
    raise ValueError(f"Invalid register format: {reg_str}")

def parse_immediate(imm_str):
    """Parse immediate value (hex or decimal) and return as integer"""
    imm_str = imm_str.strip()
    if imm_str.startswith('0x') or imm_str.startswith('0X'):
        return int(imm_str, 16)
    elif imm_str.startswith('-'):
        return int(imm_str)
    else:
        return int(imm_str)

def sign_extend_17(value):
    """Sign extend a value to 17 bits"""
    if value & 0x10000:  # Check if bit 16 is set (negative)
        return value | 0xFFFFE0000  # Sign extend to 32 bits, then mask to 17
    return value & 0x1FFFF

def encode_r_type(rd, rs, rt, shamt, aluop):
    """Encode R-type instruction"""
    instruction = (OPCODE_R_TYPE << 27) | (rd << 22) | (rs << 17) | (rt << 12) | (shamt << 7) | (aluop << 2)
    return instruction & 0xFFFFFFFF

def encode_i_type(opcode, rd, rs, imm):
    """Encode I-type instruction"""
    imm_17 = sign_extend_17(imm) & 0x1FFFF
    instruction = (opcode << 27) | (rd << 22) | (rs << 17) | imm_17
    return instruction & 0xFFFFFFFF

def encode_j_type(opcode, target):
    """Encode J-type instruction"""
    target_27 = target & 0x7FFFFFF
    instruction = (opcode << 27) | target_27
    return instruction & 0xFFFFFFFF

def parse_instruction(line, labels, pc):
    """Parse a single instruction line and return encoded instruction"""
    # Remove comments (everything after #, but handle # in strings/hex carefully)
    # Find the first # that's not part of a hex number (0x...)
    comment_pos = -1
    i = 0
    while i < len(line):
        if line[i] == '#':
            # Check if it's part of 0x... (hex number)
            if i > 1 and line[i-1] == 'x' and line[i-2] == '0':
                i += 1
                continue
            comment_pos = i
            break
        i += 1
    
    if comment_pos >= 0:
        line = line[:comment_pos]
    line = line.strip()
    if not line:
        return None
    
    # Handle labels (they're already processed, but check for label: instruction)
    if ':' in line:
        parts = line.split(':', 1)
        label = parts[0].strip()
        line = parts[1].strip()
        if not line:
            return None
    
    # Split into instruction and operands
    parts = line.split(None, 1)
    if not parts:
        return None
    
    mnemonic = parts[0].lower()
    operands = parts[1] if len(parts) > 1 else ""
    
    # Parse operands
    ops = [op.strip() for op in re.split(r'[,\s]+', operands) if op.strip()]
    
    try:
        if mnemonic == 'add':
            # add $rd, $rs, $rt
            rd = parse_register(ops[0])
            rs = parse_register(ops[1])
            rt = parse_register(ops[2])
            return encode_r_type(rd, rs, rt, 0, ALUOP_ADD)
        
        elif mnemonic == 'sub':
            # sub $rd, $rs, $rt
            rd = parse_register(ops[0])
            rs = parse_register(ops[1])
            rt = parse_register(ops[2])
            return encode_r_type(rd, rs, rt, 0, ALUOP_SUB)
        
        elif mnemonic == 'and':
            # and $rd, $rs, $rt
            rd = parse_register(ops[0])
            rs = parse_register(ops[1])
            rt = parse_register(ops[2])
            return encode_r_type(rd, rs, rt, 0, ALUOP_AND)
        
        elif mnemonic == 'or':
            # or $rd, $rs, $rt
            rd = parse_register(ops[0])
            rs = parse_register(ops[1])
            rt = parse_register(ops[2])
            return encode_r_type(rd, rs, rt, 0, ALUOP_OR)
        
        elif mnemonic == 'sll':
            # sll $rd, $rs, shamt
            rd = parse_register(ops[0])
            rs = parse_register(ops[1])
            shamt = parse_immediate(ops[2])
            return encode_r_type(rd, rs, 0, shamt, 0)  # shamt in shamt field
        
        elif mnemonic == 'sra':
            # sra $rd, $rs, shamt
            rd = parse_register(ops[0])
            rs = parse_register(ops[1])
            shamt = parse_immediate(ops[2])
            return encode_r_type(rd, rs, 0, shamt, 0b101)  # sra uses aluop 5 (0b101)
        
        elif mnemonic == 'addi':
            # addi $rd, $rs, imm
            rd = parse_register(ops[0])
            rs = parse_register(ops[1])
            imm = parse_immediate(ops[2])
            return encode_i_type(OPCODE_ADDI, rd, rs, imm)
        
        elif mnemonic == 'lw':
            # lw $rd, offset($rs)
            rd = parse_register(ops[0])
            # Parse offset($rs) format
            mem_match = re.match(r'(-?\d+)\s*\(\s*\$(\d+)\s*\)', ops[1])
            if mem_match:
                offset = int(mem_match.group(1))
                rs = int(mem_match.group(2))
            else:
                # Try simple format: lw $rd, offset, $rs
                offset = parse_immediate(ops[1])
                rs = parse_register(ops[2]) if len(ops) > 2 else 0
            return encode_i_type(OPCODE_LW, rd, rs, offset)
        
        elif mnemonic == 'sw':
            # sw $rt, offset($rs)
            rt = parse_register(ops[0])
            # Parse offset($rs) format
            mem_match = re.match(r'(-?\d+)\s*\(\s*\$(\d+)\s*\)', ops[1])
            if mem_match:
                offset = int(mem_match.group(1))
                rs = int(mem_match.group(2))
            else:
                # Try simple format: sw $rt, offset, $rs
                offset = parse_immediate(ops[1])
                rs = parse_register(ops[2]) if len(ops) > 2 else 0
            return encode_i_type(OPCODE_SW, rt, rs, offset)
        
        elif mnemonic == 'bne':
            # bne $rs, $rt, label
            rs = parse_register(ops[0])
            rt = parse_register(ops[1])
            # Check if operand is a label
            label = ops[2]
            if label in labels:
                target_pc = labels[label]
                # PC-relative: imm = target_pc - (pc - 1)
                imm = target_pc - (pc - 1)
            else:
                imm = parse_immediate(ops[2])
            return encode_i_type(OPCODE_BNE, rt, rs, imm)
        
        elif mnemonic == 'blt':
            # blt $rs, $rt, label
            rs = parse_register(ops[0])
            rt = parse_register(ops[1])
            # Check if operand is a label
            label = ops[2]
            if label in labels:
                target_pc = labels[label]
                imm = target_pc - (pc - 1)
            else:
                imm = parse_immediate(ops[2])
            return encode_i_type(OPCODE_BLT, rt, rs, imm)
        
        elif mnemonic == 'j':
            # j label
            label = ops[0]
            if label in labels:
                target = labels[label]
            else:
                target = parse_immediate(ops[0])
            return encode_j_type(OPCODE_J, target)
        
        elif mnemonic == 'jal':
            # jal label
            label = ops[0]
            if label in labels:
                target = labels[label]
            else:
                target = parse_immediate(ops[0])
            return encode_j_type(OPCODE_JAL, target)
        
        elif mnemonic == 'jr':
            # jr $rs
            rs = parse_register(ops[0])
            return encode_j_type(OPCODE_JR, rs)
        
        elif mnemonic == 'setx':
            # setx imm
            imm = parse_immediate(ops[0])
            return encode_j_type(OPCODE_SETX, imm)
        
        elif mnemonic == 'bex':
            # bex label (uses $30 as source)
            label = ops[0]
            if label in labels:
                target = labels[label]
            else:
                target = parse_immediate(ops[0])
            return encode_j_type(OPCODE_BEX, target)
        
        elif mnemonic == 'andi':
            # andi $rd, $rs, imm
            # The CPU doesn't have andi, so we need to work around it
            # We can't easily do this in one instruction, so we'll encode as NOP
            # The assembly code should be fixed to use: 
            #   addi $temp, $0, imm
            #   and $rd, $rs, $temp
            # For now, encode as NOP and warn
            print(f"Warning: andi instruction not supported by CPU. Encoding as NOP.", file=sys.stderr)
            print(f"  Consider replacing 'andi {ops[0]}, {ops[1]}, {ops[2]}' with:", file=sys.stderr)
            print(f"    addi $29, $0, {ops[2]}", file=sys.stderr)
            print(f"    and {ops[0]}, {ops[1]}, $29", file=sys.stderr)
            return 0  # NOP - this will need to be fixed in assembly
        
        else:
            raise ValueError(f"Unknown instruction: {mnemonic}")
    
    except (IndexError, ValueError) as e:
        raise ValueError(f"Error parsing instruction '{line}': {e}")

def assemble_file(input_file, output_file):
    """Assemble an assembly file into a memory file"""
    with open(input_file, 'r') as f:
        lines = f.readlines()
    
    # First pass: collect labels
    labels = {}
    pc = 0
    in_text = False
    
    for line in lines:
        line = line.strip()
        # Skip empty lines and comments
        if not line or line.startswith('#'):
            continue
        
        # Handle directives
        if line.startswith('.text'):
            in_text = True
            continue
        elif line.startswith('.data'):
            in_text = False
            continue
        
        # Handle labels
        if ':' in line and in_text:
            label = line.split(':')[0].strip()
            labels[label] = pc
            # Check if there's an instruction on the same line
            if ':' in line and len(line.split(':')) > 1:
                remaining = line.split(':', 1)[1].strip()
                if remaining and not remaining.startswith('#'):
                    pc += 1
        elif in_text:
            # Count instructions
            if line.split('#')[0].strip():  # Non-empty after removing comments
                pc += 1
    
    # Second pass: assemble instructions
    instructions = []
    pc = 0
    in_text = False
    
    for line_num, original_line in enumerate(lines, 1):
        line = original_line.strip()
        
        # Skip empty lines
        if not line or line.startswith('#'):
            continue
        
        # Handle directives
        if line.startswith('.text'):
            in_text = True
            continue
        elif line.startswith('.data'):
            in_text = False
            continue
        
        # Skip labels (they're already processed)
        if ':' in line and in_text:
            # Check if there's an instruction after the label
            # Only split if ':' appears before any '#' (i.e., it's a label, not in comment)
            comment_pos = line.find('#')
            colon_pos = line.find(':')
            if comment_pos == -1 or colon_pos < comment_pos:
                # ':' is before '#' or no comment, so it's a label
                parts = line.split(':', 1)
                if len(parts) > 1:
                    line = parts[1].strip()
                    if not line or line.startswith('#'):
                        continue
                else:
                    continue
        
        if in_text:
            try:
                # Debug: print what we're trying to parse
                # print(f"DEBUG: Parsing line {line_num}: '{line}'", file=sys.stderr)
                instruction = parse_instruction(line, labels, pc)
                if instruction is not None:
                    instructions.append(instruction)
                    pc += 1
            except ValueError as e:
                print(f"Error at line {line_num}: {original_line.strip()}", file=sys.stderr)
                print(f"  Parsing: '{line}'", file=sys.stderr)
                print(f"  {e}", file=sys.stderr)
                sys.exit(1)
    
    # Write output file
    with open(output_file, 'w') as f:
        for instruction in instructions:
            f.write(f"{instruction:08X}\n")
    
    print(f"Assembled {len(instructions)} instructions to {output_file}")

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python assemble.py <input.s> <output.mem>", file=sys.stderr)
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    try:
        assemble_file(input_file, output_file)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

