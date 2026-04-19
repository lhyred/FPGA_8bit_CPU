# 1. CPU 基本规格

- **数据宽度**：8 位
    
- **地址宽度**：8 位
    
- **指令长度**：16 位
    
- **存储结构**：Harvard
    
    - 指令存储：`instr_rom`
        
    - 数据存储：`data_ram`
        
- **执行方式**：多周期
    
    - `FETCH`
        
    - `DECODE`
        
    - `EXEC`
        
    - `MEM`
        
    - `WRITEBACK`
        
    - `HALT`
        

---

# 2. 寄存器定义

当前设计中有 4 个 8 位通用寄存器：

- `R0`
    
- `R1`
    
- `R2`
    
- `R3`
    

寄存器编号是 2 位：

- `R0 = 2'b00`
    
- `R1 = 2'b01`
    
- `R2 = 2'b10`
    
- `R3 = 2'b11`
    

---

# 3. 指令格式

所有指令都是 **16 位定长**：

```text
[15:12] opcode
[11:10] rd
[ 9: 8] rs
[ 7: 0] imm/addr
```

含义：

- `opcode`：操作码，4 位
    
- `rd`：目标寄存器
    
- `rs`：源寄存器
    
- `imm/addr`：8 位立即数或地址
    

注意：

- 对某些指令来说，`rd / rs / imm` 不一定都有效
    
- 无效字段一般填 `0` 即可

### 标志位说明

- `Z`：零标志，ALU 运算结果为 0 时置位
- `C`：进位 / 借位标志

说明：

- `ADD / SUB / AND / OR / XOR / NOT / SHL / SHR` 会更新标志位
- `LDI / MOV / LOAD / STORE / JMP / JZ / JC / HLT` 不更新标志位

---

# 4. 指令总表

## 4.1 数据传送类

| 指令                 | opcode | 语义                   |
| ------------------ | -----: | -------------------- |
| `LDI rd, imm`      |  `0x0` | `R[rd] <- imm`       |
| `MOV rd, rs`       |  `0x1` | `R[rd] <- R[rs]`     |
| `LOAD rd, [addr]`  |  `0x2` | `R[rd] <- MEM[addr]` |
| `STORE rs, [addr]` |  `0x3` | `MEM[addr] <- R[rs]` |

---

## 4.2 算术逻辑类

| 指令           | opcode | 语义                        |
| ------------ | -----: | ------------------------- |
| `ADD rd, rs` |  `0x4` | `R[rd] <- R[rd] + R[rs]`  |
| `SUB rd, rs` |  `0x5` | `R[rd] <- R[rd] - R[rs]`  |
| `AND rd, rs` |  `0x6` | `R[rd] <- R[rd] & R[rs]`  |
| `OR rd, rs`  |  `0x7` | `R[rd] <- R[rd] \| R[rs]` |
| `XOR rd, rs` |  `0x8` | `R[rd] <- R[rd] ^ R[rs]`  |
| `NOT rd`     |  `0x9` | `R[rd] <- ~R[rd]`         |
| `SHL rd`     |  `0xA` | `R[rd] <- R[rd] << 1`     |
| `SHR rd`     |  `0xB` | `R[rd] <- R[rd] >> 1`     |

---

## 4.3 控制流类

| 指令         | opcode | 语义                      |
| ---------- | -----: | ----------------------- |
| `JMP addr` |  `0xC` | `PC <- addr`            |
| `JZ addr`  |  `0xD` | 若 `Z==1`，则 `PC <- addr` |
| `JC addr`  |  `0xE` | 若 `C==1`，则 `PC <- addr` |
| `HLT`      |  `0xF` | 停机                      |

---

# 5. 各条指令的具体用法

## 5.1 `LDI rd, imm`

把 8 位立即数送入寄存器。

### 语法

```text
LDI rd, imm
```

### 语义

```text
R[rd] <- imm
```

### 例子

```text
LDI R0, 0x25
```

效果：

```text
R0 = 0x25
```

---

## 5.2 `MOV rd, rs`

寄存器到寄存器传送。

### 语法

```text
MOV rd, rs
```

### 语义

```text
R[rd] <- R[rs]
```

### 例子

```text
MOV R2, R1
```

效果：

```text
R2 = R1
```

---

## 5.3 `LOAD rd, [addr]`

从数据 RAM 指定地址读一个字节到寄存器。

### 语法

```text
LOAD rd, [addr]
```

### 语义

```text
R[rd] <- MEM[addr]
```

### 例子

```text
LOAD R3, [0x20]
```

效果：

```text
R3 = MEM[0x20]
```

---

## 5.4 `STORE rs, [addr]`

把寄存器内容写入数据 RAM。

### 语法

```text
STORE rs, [addr]
```

### 语义

```text
MEM[addr] <- R[rs]
```

### 例子

```text
STORE R1, [0x20]
```

效果：

```text
MEM[0x20] = R1
```

**注意**：当前这套实现里，`STORE` 用的是 `rs`，不是 `rd`。这是因为顶层数据通路当前把 RAM 的写数据接到了寄存器堆第二读口，也就是 `rf_rdata2 = R[rs]`。这一点和最初建议接口相比，已经在实际实现里固定下来了。

---

## 5.5 `ADD rd, rs`

### 语法

```text
ADD rd, rs
```

### 语义

```text
R[rd] <- R[rd] + R[rs]
```

### 例子

```text
ADD R0, R1
```

效果：

```text
R0 = R0 + R1
```

会更新标志位：

- `Z`：结果是否为 0
    
- `C`：加法是否产生进位
    

---

## 5.6 `SUB rd, rs`

### 语法

```text
SUB rd, rs
```

### 语义

```text
R[rd] <- R[rd] - R[rs]
```

### 例子

```text
SUB R2, R3
```

效果：

```text
R2 = R2 - R3
```

会更新：

- `Z`
    
- `C`
    

这里当前 ALU 的 `C` 对减法表示**借位位**。

---

## 5.7 `AND rd, rs`

```text
R[rd] <- R[rd] & R[rs]
```

例子：

```text
AND R0, R1
```

---

## 5.8 `OR rd, rs`

```text
R[rd] <- R[rd] | R[rs]
```

例子：

```text
OR R0, R1
```

---

## 5.9 `XOR rd, rs`

```text
R[rd] <- R[rd] ^ R[rs]
```

例子：

```text
XOR R0, R1
```

---

## 5.10 `NOT rd`

单目运算，只对 `rd` 生效。

### 语法

```text
NOT rd
```

### 语义

```text
R[rd] <- ~R[rd]
```

### 例子

```text
NOT R2
```

---

## 5.11 `SHL rd`

左移 1 位。

### 语义

```text
R[rd] <- R[rd] << 1
```

### 例子

```text
SHL R0
```

会更新：

- `Z`
    
- `C`，其中 `C = 原来的最高位`
    

---

## 5.12 `SHR rd`

右移 1 位。

### 语义

```text
R[rd] <- R[rd] >> 1
```

### 例子

```text
SHR R0
```

会更新：

- `Z`
    
- `C`，其中 `C = 原来的最低位`
    

---

## 5.13 `JMP addr`

无条件跳转。

### 语法

```text
JMP addr
```

### 语义

```text
PC <- addr
```

### 例子

```text
JMP 0x30
```

---

## 5.14 `JZ addr`

当零标志 `Z=1` 时跳转。

### 语法

```text
JZ addr
```

### 语义

```text
if (Z == 1) PC <- addr
```

### 常见用法

先做一次运算，再根据结果是否为 0 来跳转：

```text
SUB R0, R1
JZ  0x20
```

---

## 5.15 `JC addr`

当进位/借位标志 `C=1` 时跳转。

### 语法

```text
JC addr
```

### 语义

```text
if (C == 1) PC <- addr
```

### 常见用法

```text
ADD R0, R1
JC  0x40
```

或者减法后判断借位：

```text
SUB R0, R1
JC  0x50
```

---

## 5.16 `HLT`

停机指令。

### 语法

```text
HLT
```

### 语义

```text
CPU 进入 HALT 状态，不再继续执行
```

---

# 6. 标志位说明

当前 CPU 至少有两个标志位：

- `Z`：Zero，结果是否为 0
    
- `C`：Carry，加法进位 / 减法借位 / 移位移出的位
    

这些标志位主要由 ALU 类指令更新：

- `ADD`
    
- `SUB`
    
- `AND`
    
- `OR`
    
- `XOR`
    
- `NOT`
    
- `SHL`
    
- `SHR`
    

传送类和跳转类通常不更新标志位。这个设计也符合你最初对 `flags` 和 `JZ / JC` 的需求。

---

# 7. 机器码写法总结

16 位机器码格式：

```text
[15:12] opcode
[11:10] rd
[ 9: 8] rs
[ 7: 0] imm/addr
```

---

## 示例 1：`LDI R0, 0x05`

- opcode = `0`
    
- rd = `00`
    
- rs = `00`
    
- imm = `05`
    

结果：

```text
0000 0000 0000 0101 = 16'h0005
```

---

## 示例 2：`LDI R1, 0x03`

- opcode = `0`
    
- rd = `01`
    
- rs = `00`
    
- imm = `03`
    

结果：

```text
0000 0100 0000 0011 = 16'h0403
```

---

## 示例 3：`ADD R0, R1`

- opcode = `4`
    
- rd = `00`
    
- rs = `01`
    
- imm = `00`
    

结果：

```text
0100 0001 0000 0000 = 16'h4100
```

---

## 示例 4：`STORE R0, [0x10]`

这里按当前实现，`STORE` 的寄存器字段是 `rs`：

- opcode = `3`
    
- rd = `00`
    
- rs = `00`
    
- addr = `10`
    

结果：

```text
0011 0000 0001 0000 = 16'h3010
```

---

## 示例 5：`LOAD R2, [0x10]`

- opcode = `2`
    
- rd = `10`
    
- rs = `00`
    
- addr = `10`
    

结果：

```text
0010 1000 0001 0000 = 16'h2810
```

---

## 示例 6：`HLT`

结果：

```text
1111 0000 0000 0000 = 16'hF000
```

---

# 8. 一个完整小程序示例

```text
LDI   R0, 0x05
LDI   R1, 0x03
ADD   R0, R1
STORE R0, [0x10]
LOAD  R2, [0x10]
HLT
```

对应 `prog.mem`：

```text
0005
0403
4100
3010
2810
F000
```

执行后效果：

- `R0 = 0x08`
    
- `R1 = 0x03`
    
- `MEM[0x10] = 0x08`
    
- `R2 = 0x08`
    

---

# 9. 当前版本最重要的实现约定

后面写程序时，你只要记住这几条就不容易错：

- `ADD/SUB/AND/OR/XOR` 都是  
    `R[rd] <- R[rd] op R[rs]`
    
- `NOT/SHL/SHR` 只对 `rd` 自身操作
    
- `LOAD` 是  
    `R[rd] <- MEM[addr]`
    
- `STORE` 当前是  
    `MEM[addr] <- R[rs]`
    
- `JZ/JC` 判断的是前面 ALU 运算留下的标志位
    

---

# 10. 最后给你一个简版速查表

```text
LDI   rd, imm      ; R[rd] <- imm
MOV   rd, rs       ; R[rd] <- R[rs]
LOAD  rd, [addr]   ; R[rd] <- MEM[addr]
STORE rs, [addr]   ; MEM[addr] <- R[rs]

ADD   rd, rs       ; R[rd] <- R[rd] + R[rs]
SUB   rd, rs       ; R[rd] <- R[rd] - R[rs]
AND   rd, rs       ; R[rd] <- R[rd] & R[rs]
OR    rd, rs       ; R[rd] <- R[rd] | R[rs]
XOR   rd, rs       ; R[rd] <- R[rd] ^ R[rs]
NOT   rd           ; R[rd] <- ~R[rd]
SHL   rd           ; R[rd] <- R[rd] << 1
SHR   rd           ; R[rd] <- R[rd] >> 1

JMP   addr         ; PC <- addr
JZ    addr         ; if Z==1, PC <- addr
JC    addr         ; if C==1, PC <- addr
HLT                ; stop
```