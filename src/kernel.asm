org 0x7e00
bits 16

%define WIDTH 1600
%define HEIGHT 1052
%define PIXEL_SIZE 3
%define SAMPLES_PER_AXIS 3
%define SAMPLES_PER_AXIS_SQ 9 ; samples per axis squared
%define MAX_DEPTH 2
%define FOV 42
%define EPSILON 0.00001

%define CORE_NUM 22
%define FPS  60

%define COL_FLOOR_0 255.0
%define COL_FLOOR_1 255.0
%define COL_FLOOR_2 255.0

%define COL_MIRROR_0 25.5
%define COL_MIRROR_1 25.5
%define COL_MIRROR_2 25.5

%define COL_LIGHT_0 5610.0
%define COL_LIGHT_1 3825.0
%define COL_LIGHT_2 510.0

%define COL_SKY_0 1.275
%define COL_SKY_1 1.275
%define COL_SKY_2 2.55

%define MIN_CORE_REQUIREMENTS 3

section .data
align 4
lfb_addr:  dd 0
KEYS: dd 128 dup(0)
mode_info: times 256 db 0
XMM_GV_SIGN_MASK: dd 0x80000000 ; 10000000000000000000000000000000000000000000000
num_cores: dd 0
state: dd 0 ; should be equal to num_cores before switching modes both ways, from calc to graph or from graph to calc

align 8
gdt:
    dq 0x0000000000000000
    dq 0x00cf9a000000ffff
    dq 0x00cf92000000ffff
gdt_desc:
    dw gdt_desc - gdt - 1
    dd gdt

mcs_end:

section .bss
kstack: resb 100000*50 ; stack
kstack_top:
section .text
kernel_init:
    mov ax, 0x4f02
    mov bx, 0x11f | 0x4000
    int 0x10

    mov ax, 0x4f01
    mov cx, 0x11f
    mov di, mode_info
    int 0x10

    mov eax, [mode_info + 0x28]
    mov [lfb_addr], eax

    in al, 0x92
    or al, 2
    out 0x92, al

    lgdt [gdt_desc]
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    jmp 0x08:pm_start

bits 32
pm_start:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, kstack_top

    mov esi, ap_mcs
    mov edi, 0x10000
    mov ecx, mcs_end - ap_mcs
    rep movsb

    mov eax, 0xFEE00300
    mov edx, 0x000C4500
    mov [eax], edx

    mov ecx, 0x1000000
.delay: 
    loop .delay

    mov edx, 0x000C4610
    mov [eax], edx

    jmp parallel

bits 16
ap_mcs:
    cli
    xor ax, ax
    mov ds, ax
    lgdt [gdt_desc] 
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:ap_pm_entry
ap_mcs_end:

bits 32
ap_pm_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    
    mov eax, 0xFEE00020
    mov ebx, [eax]
    shr ebx, 24              
    ; right now 50 triangles per core sample
    ; and 1000 bytes worplace
    mov eax, 100000  ; max size of the stack for the core, 100*MAX_NUM_TRIANGLES + SIZE_OF_NUMBER_OF_TRIANGLES + SIZE_OF_CORE_ID + CACHE_LINE_SPACE + SIZE_OF_WORKPLACE all in bytes
    mul ebx ; ebx stays the same
    mov esp, kstack_top ; stack begin!
    sub esp, eax
    jmp parallel

graphics: ; each core jumps to this in between updating, including inactive for calculation cores, so divide by the num_cores
    mov ebx, esp
    mov ecx, ebp
    mov esp, kstack_top
    mov eax, 30 ; max num cores
    imul eax, 100000
    sub esp, eax
    and esp, -64
    push ebx ; esp 
    push ecx ; ebp
    mov ebp, esp


    mov ecx, 0
for_each_core_get_triangles:
    mov eax, kstack_top
    
    inc ecx
    cmp ecx, dword MIN_CORE_REQUIREMENTS
    jl for_each_core_get_triangles

    lock dec dword [state]
loop_back_compare_state:
    cmp dword [state], 0
    jne lock_back_compare_state

    mov esp, dword [ebp+4]
    mov ebp, dword [ebp]

    ret

parallel:
; ebx is initialized to core register
    and esp, -4 ; aligns to 4 bytes
    mov ebp, esp
    lock inc dword [num_cores]

    %define CORE_ID ebp-4
    push ebx
    sub esp, 64 ; subtract 64 to seperate core_id from the triangle cache lines

    %define NUM_TRIANGLES ebp-8

    and esp, -64 ; align to 64 bytes
    ; align to 64 bytes after each triangle too
    
    cmp dword [num_cores], MIN_CORE_REQUIREMENTS ; this doesn't meet minimum core requirements
    jne force_quit

    cmp ebx, 0
    je core_0
    cmp ebx, 1
    je core_1
    cmp ebx, 2
    je core_2

    jmp core_unassigned

; ok so basically here we define objects owned by cores
; you don't have to use all cores
; in each core, you have to call the graphics function, then do the updating calculations
; then it jumps back to wherever

core_0:
      ; model test section one
          push 8 ; how many triangles there are
          push -0.6
          push 1.6
          push -0.8
          push 0.0
          push -1.6
          push 0.0
          push -1.6
          push -1.6
          push 0.0
          push 0.0
          push -0.0
          push -1.0
          push 25.5
          push 25.5
          push 25.5
          push 1
          push -1.1333
          push 0.5333
          push -0.8
          push -2.2
          push 0.0
          push -0.8
          push -0.6
          push 1.6
          push -0.8

          push -2.2
          push 1.6
          push -0.8
          push 1.6
          push 0.0
          push 0.0
          push 0.0
          push -1.6
          push 0.0
          push 0.0
          push 0.0
          push -1.0
          push 25.5
          push 25.5
          push 25.5
          push 1
          push -1.6667
          push 1.0667
          push -0.8
          push -2.2
          push 0.0
          push -0.8
          push -0.6
          push 1.6
          push -0.8

          push -2.2
          push 0.0
          push 0.8
          push 1.6
          push 0.0
          push 0.0
          push 1.6
          push 1.6
          push 0.0
          push 0.0
          push 0.0
          push 1.0
          push 25.5
          push 25.5
          push 25.5
          push 1
          push -1.1333
          push 0.5333
          push 0.8
          push -2.2
          push 0.0
          push 0.8
          push -0.6
          push 1.6
          push 0.8

          push -2.2
          push 0.0
          push 0.8
          push 1.6
          push 1.6
          push 0.0
          push 0.0
          push 1.6
          push 0.0
          push 0.0
          push 0.0
          push 1.0
          push 25.5
          push 25.5
          push 25.5
          push 1
          push -1.6667
          push 1.0667
          push 0.8
          push -2.2
          push 0.0
          push 0.8
          push -0.6
          push 1.6
          push 0.8

          push -2.2
          push 0.0
          push -0.8
          push 0.0
          push 0.0
          push 1.6
          push 0.0
          push 1.6
          push 1.6
          push -1.0
          push 0.0
          push 0.0
          push 25.5
          push 25.5
          push 25.5
          push 1
          push -2.2
          push 0.5333
          push 0.2667
          push -2.2
          push 0.0
          push -0.8
          push -2.2
          push 1.6
          push 0.8

          push -2.2
          push 0.0
          push -0.8
          push 0.0
          push 1.6
          push 1.6
          push 0.0
          push 1.6
          push 0.0
          push -1.0
          push 0.0
          push 0.0
          push 25.5
          push 25.5
          push 25.5
          push 1
          push -2.2
          push 1.0667
          push -0.2667
          push -2.2
          push 0.0
          push -0.8
          push -2.2
          push 1.6
          push 0.8

          push -0.6
          push 1.6
          push 0.8
          push 0.0
          push -1.6
          push 0.0
          push 0.0
          push -1.6
          push -1.6
          push 1.0
          push 0.0
          push 0.0
          push 25.5
          push 25.5
          push 25.5
          push 1
          push -0.6
          push 0.5333
          push 0.2667
          push -0.6
          push 0.0
          push -0.8
          push -0.6
          push 1.6
          push 0.8

          push -0.6
          push 1.6
          push -0.8
          push 0.0
          push 0.0
          push 1.6
          push 0.0
          push -1.6
          push 0.0
          push 1.0
          push 0.0
          push -0.0
          push 25.5
          push 25.5
          push 25.5
          push 1
          push -0.6
          push 1.0667
          push -0.2667
          push -0.6
          push 0.0
          push -0.8
          push -0.6
          push 1.6
          push 0.8
      ; model test section one end
    ; define objects of triangles here
    ; then have an infinite loop while calling graphics after all calculations

core_0_update:
    
; shift escape then program needs to be killed
force_quit_check:
    in al, 0x64
    test al, 1
    jz force_quit_check_done
    in al, 0x60
    cmp al, 0x80
    jb force_quit_check_pressed
    sub al, 0x80
    mov byte [KEYS+eax], 0
    jmp force_quit_check_done

force_quit_check_pressed:
    mov byte [KEYS+eax], 1

force_quit_check_done:
    cmp byte [KEYS+0x01], 1
    jne force_quit_check_false
    sub byte [KEYS+0x01], 1
    jmp force_quit_check_esc_pressed_true

force_quit_check_esc_pressed_true:
    cmp byte [KEYS+0x2A], 1
    jne force_quit_check_false
    sub byte [KEYS+0x2A], 1
    jmp force_quit

force_quit_check_false:

    lock inc dword [state]
loop_forward_compare_state_core_0:
    cmp dword [state], dword [num_cores]
    jne loop_forward_compare_state_core_0
    call graphics
    jmp core_0_update

core_1:

          push 8 ; how many triangles there are
          push -2.2
          push 0.0
          push -0.8
          push 1.6
          push 0.0
          push 0.0
          push 1.6
          push 0.0
          push 1.6
          push 0.0
          push -1.0
          push 0.0
          push 25.5
          push 25.5
          push 25.5
          push 1
          push -1.1333
          push 0.0
          push -0.2667
          push -2.2
          push 0.0
          push -0.8
          push -0.6
          push 0.0
          push 0.8

          push -2.2
          push 0.0
          push -0.8
          push 1.6
          push 0.0
          push 1.6
          push 0.0
          push 0.0
          push 1.6
          push 0.0
          push -1.0
          push 0.0
          push 25.5
          push 25.5
          push 25.5
          push 1
          push -1.6667
          push 0.0
          push 0.2667
          push -2.2
          push 0.0
          push -0.8
          push -0.6
          push 0.0
          push 0.8

          push -0.6
          push 1.6
          push 0.8
          push 0.0
          push 0.0
          push -1.6
          push -1.6
          push 0.0
          push -1.6
          push 0.0
          push 1.0
          push 0.0
          push 25.5
          push 25.5
          push 25.5
          push 1
          push -1.1333
          push 1.6
          push -0.2667
          push -2.2
          push 1.6
          push -0.8
          push -0.6
          push 1.6
          push 0.8

          push -2.2
          push 1.6
          push 0.8
          push 1.6
          push 0.0
          push 0.0
          push 0.0
          push 0.0
          push -1.6
          push -0.0
          push 1.0
          push 0.0
          push 25.5
          push 25.5
          push 25.5
          push 1
          push -1.6667
          push 1.6
          push 0.2667
          push -2.2
          push 1.6
          push -0.8
          push -0.6
          push 1.6
          push 0.8

          push 2.2
          push 1.6
          push -0.8
          push 0.0
          push -1.6
          push 0.0
          push -1.6
          push -1.6
          push 0.0
          push 0.0
          push -0.0
          push -1.0
          push 5610.0
          push 3825.0
          push 510.0
          push 2
          push 1.6667
          push 0.5333
          push -0.8
          push 0.6
          push 0.0
          push -0.8
          push 2.2
          push 1.6
          push -0.8

          push 0.6
          push 1.6
          push -0.8
          push 1.6
          push 0.0
          push 0.0
          push 0.0
          push -1.6
          push 0.0
          push 0.0
          push 0.0
          push -1.0
          push 5610.0
          push 3825.0
          push 510.0
          push 2
          push 1.1333
          push 1.0667
          push -0.8
          push 0.6
          push 0.0
          push -0.8
          push 2.2
          push 1.6
          push -0.8

          push 0.6
          push 0.0
          push 0.8
          push 1.6
          push 0.0
          push 0.0
          push 1.6
          push 1.6
          push 0.0
          push 0.0
          push 0.0
          push 1.0
          push 5610.0
          push 3825.0
          push 510.0
          push 2
          push 1.6667
          push 0.5333
          push 0.8
          push 0.6
          push 0.0
          push 0.8
          push 2.2
          push 1.6
          push 0.8

          push 0.6
          push 0.0
          push 0.8
          push 1.6
          push 1.6
          push 0.0
          push 0.0
          push 1.6
          push 0.0
          push 0.0
          push 0.0
          push 1.0
          push 5610.0
          push 3825.0
          push 510.0
          push 2
          push 1.1333
          push 1.0667
          push 0.8
          push 0.6
          push 0.0
          push 0.8
          push 2.2
          push 1.6
          push 0.8
    ; then have an infinite loop while calling graphics after all calculations

core_1_update:
; this is an example for when you're done with core 1 code, if you want core 2 to access it too !!!!!!!!!!!!!!!
; core 1 normal code is here
; mov dword [CORE_ID], 2
; wait_for_core_2_to_finish_with_core_1:
; cmp dword [CORE_ID], 1
; jne wait_for_core_2_to_finish_with_core_1


    lock inc dword [state]
loop_forward_compare_state_core_1:
    cmp dword [state], dword [num_cores]
    jne loop_forward_compare_state_core_1
    call graphics
    jmp core_1_update

core_2:
          push 8 ; how many triangles there are
          push 0.6
          push 0.0
          push -0.8
          push 0.0
          push 0.0
          push 1.6
          push 0.0
          push 1.6
          push 1.6
          push -1.0
          push 0.0
          push 0.0
          push 5610.0
          push 3825.0
          push 510.0
          push 2
          push 0.6
          push 0.5333
          push 0.2667
          push 0.6
          push 0.0
          push -0.8
          push 0.6
          push 1.6
          push 0.8

          push 0.6
          push 0.0
          push -0.8
          push 0.0
          push 1.6
          push 1.6
          push 0.0
          push 1.6
          push 0.0
          push -1.0
          push 0.0
          push 0.0
          push 5610.0
          push 3825.0
          push 510.0
          push 2
          push 0.6
          push 1.0667
          push -0.2667
          push 0.6
          push 0.0
          push -0.8
          push 0.6
          push 1.6
          push 0.8

          push 2.2
          push 1.6
          push 0.8
          push 0.0
          push -1.6
          push 0.0
          push 0.0
          push -1.6
          push -1.6
          push 1.0
          push 0.0
          push 0.0
          push 5610.0
          push 3825.0
          push 510.0
          push 2
          push 2.2
          push 0.5333
          push 0.2667
          push 2.2
          push 0.0
          push -0.8
          push 2.2
          push 1.6
          push 0.8

          push 2.2
          push 1.6
          push -0.8
          push 0.0
          push 0.0
          push 1.6
          push 0.0
          push -1.6
          push 0.0
          push 1.0
          push 0.0
          push -0.0
          push 5610.0
          push 3825.0
          push 510.0
          push 2
          push 2.2
          push 1.0667
          push -0.2667
          push 2.2
          push 0.0
          push -0.8
          push 2.2
          push 1.6
          push 0.8

          push 0.6
          push 0.0
          push -0.8
          push 1.6
          push 0.0
          push 0.0
          push 1.6
          push 0.0
          push 1.6
          push 0.0
          push -1.0
          push 0.0
          push 5610.0
          push 3825.0
          push 510.0
          push 2
          push 1.6667
          push 0.0
          push -0.2667
          push 0.6
          push 0.0
          push -0.8
          push 2.2
          push 0.0
          push 0.8

          push 0.6
          push 0.0
          push -0.8
          push 1.6
          push 0.0
          push 1.6
          push 0.0
          push 0.0
          push 1.6
          push 0.0
          push -1.0
          push 0.0
          push 5610.0
          push 3825.0
          push 510.0
          push 2
          push 1.1333
          push 0.0
          push 0.2667
          push 0.6
          push 0.0
          push -0.8
          push 2.2
          push 0.0
          push 0.8

          push 2.2
          push 1.6
          push 0.8
          push 0.0
          push 0.0
          push -1.6
          push -1.6
          push 0.0
          push -1.6
          push 0.0
          push 1.0
          push 0.0
          push 5610.0
          push 3825.0
          push 510.0
          push 2
          push 1.6667
          push 1.6
          push -0.2667
          push 0.6
          push 1.6
          push -0.8
          push 2.2
          push 1.6
          push 0.8

          push 0.6
          push 1.6
          push 0.8
          push 1.6
          push 0.0
          push 0.0
          push 0.0
          push 0.0
          push -1.6
          push -0.0
          push 1.0
          push 0.0
          push 5610.0
          push 3825.0
          push 510.0
          push 2
          push 1.1333
          push 1.6
          push 0.2667
          push 0.6
          push 1.6
          push -0.8
          push 2.2
          push 1.6
          push 0.8
    ; define objects of triangles here
    ; then have an infinite loop while calling graphics after all calculations

core_2_update:
; this is an example for when you're done with core 1 code, if you want core 2 to access it too !!!!!!!!!!!!!!!
; core 2 normal code is here
; mov eax, {calculation to find core 1 id} 
; wait_for_core_1_to_finish_with_core_1_from_core_2:
; cmp dword [eax], 2
; jne wait_for_core_1_to_finish_with_core_1_from_core_2
; DO OPERATIONS ON CORE_1 OBJECTS HERE
; mov dword [eax], 1



    lock inc dword [state]
loop_forward_compare_state_core_2:
    cmp dword [state], dword [num_cores]
    jne loop_forward_compare_state_core_2
    call graphics
    jmp core_2_update

core_unassigned:
    lock inc dword [state]
loop_forward_compare_state_core_unassigned:
    cmp dword [state], dword [num_cores]
    jne loop_forward_compare_state_core_unassigned
    call graphics
    jmp core_unassigned







force_quit:
    mov ebp, lfb_addr + (WIDTH * HEIGHT)
    mov esp, lfb_addr

set_screen_to_black:
    cmp esp, ebp
    je actual_force_quit

    mov byte [esp], 0x00
    inc esp
    jmp set_screen_to_black

actual_force_quit:
    cli
    hlt
    jmp $
