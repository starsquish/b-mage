org 0x7e00
bits 16

%define WIDTH 1600
%define HEIGHT 1052
%define PIXEL_SIZE 3
%define SAMPLES_PER_AXIS 1
%define SAMPLES_PER_AXIS_SQ 1 ; samples per axis squared
%define MAX_DEPTH 1
%define FOV 42

%define CORE_NUM 22
%define FPS 60

%define COL_FLOOR_0 255.0
%define COL_FLOOR_1 255.0
%define COL_FLOOR_2 255.0

%define COL_MIRROR_0 25.5
%define COL_MIRROR_1 25.5
%define COL_MIRROR_2 25.5

%define COL_LIGHT_0 8000.0
%define COL_LIGHT_1 6000.0
%define COL_LIGHT_2 1000.0

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
    mov edi, esp
    mov ecx, ebp
    mov esp, kstack_top
    mov eax, 30 ; max num cores
    imul eax, 100000
    sub esp, eax
    and esp, -64
    @push edi ; esp 
    @push ecx ; ebp
    mov ebp, esp
    @push ebx ; [ebp-4]
    @push 0 ; this 0 is just for padding to 16 bit alignment

    %define WIDTH_CONSIDERING_SIZE 533
    %define HEIGHT_CONSIDERING_SIZE 350
    
    %define cp_0 3.5
    %define cp_1 3.5
    %define cp_2 -7.0

    %define fw_0 -0.419
    %define fw_1 -0.347
    %define fw_2 0.839

    %define rt_0 -0.895
    %define rt_1 0.0
    %define rt_2 -0.447

    %define up_0 -0.155
    %define up_1 0.938
    %define up_2 0.311

    %define sca 0.384
    %define asp 1.523 

    %define cube1 edi
    %define cube2 esi

    mov edi, kstack_top
    sub edi, 100000

    mov esi, edi
    sub esi, 100000
    
    and edi, -4
    and esi, -4
    sub edi, 68
    sub esi, 68
    and edi, -64
    and esi, -64
    sub edi, 4
    sub esi, 4
    and esi, -64
    and edi, -64


    mov ebx, [ebp-4]*(HEIGHT_CONSIDERING_SIZE / CORE_NUM)
    for_y_loop:
        cmp ebx, ([ebp-4] + 1)*(HEIGHT_CONSIDERING_SIZE / CORE_NUM)
        jge skip_for_y_loop
        mov ecx, [ebp-4]*(WIDTH_CONSIDERING_SIZE / CORE_NUM)
        for_x_loop:
          cmp ecx, ([ebp-4] + 1)*(WIDTH_CONSIDERING_SIZE / CORE_NUM)
          jge skip_for_x_loop
          vmovd xmm0, ebx
          vbroadcastss xmm0, xmm0
          vcvtdq2ps xmm0, xmm0

          vmovd xmm1, ecx
          vbroadcastss xmm1, xmm1
          vcvtdq2ps xmm1, xmm1

          vmovaps xmm2, xmm0 ; y
          vmovaps xmm3, xmm1 ; x

          %define u xmm3
          %define v xmm2

          ; @PUSH PUSHES THE HEX REPRESENTATION OF A FLOAT OTHERWISE JUST USES NORMAL PUSH
          @push 0.005
          vmulps u, u, [esp]

          @push -0.511
          vaddps u, u, [esp]

          @push -0.005
          vmulps v, v, [esp]

          @push 0.381
          vaddps v, v, [esp]

          @push fw_0
          @push fw_1
          @push fw_2
          @push 0.0

          vmovaps xmm4, [esp+12]

          @push rt_0
          @push rt_1
          @push rt_2
          @push 0.0

          vmovaps xmm5, [esp+12]

          @push up_0
          @push up_1
          @push up_2
          @push 0.0
          
          vmovaps xmm6, [esp+12]

          vmulps xmm5, xmm5, u
          vmulps xmm6, xmm6, v
          vaddps xmm4, xmm4, xmm5
          vaddps xmm4, xmm4, xmm6

          vmovaps xmm2, xmm4 ; now has copy of xmm4 because xmm4 is going to become a single value now

          vmulps xmm4, xmm4, xmm4
          vhaddps xmm4, xmm4, xmm4
          vhaddps xmm4, xmm4, xmm4 ; meant to be twice, look at the instruction spec again if confused
          vsqrtps xmm4, xmm4

          vdivps xmm2, xmm2, xmm4

          add esp, 4*16
          


          %define rd xmm2
          %define ro xmm7
          @push cp_0
          @push cp_1
          @push cp_2
          @push 0.0
          vmovaps xmm7, [esp+12]
          add esp, 4*4

          @push 0.0 ; [ebp-12] color_acc
          @push 0.0
          @push 0.0
          @push 0.0
          @push 1.0 ; [ebp-28] reflect_weight

          mov edx, 0
          for_2_loop:
            cmp edx, 2
            jge skip_for_2_loop
            @push 10000 ; [ebp-32] t_hit
            mov eax, 0 ; eax obj

            and esp, -16
            @push 0.0 ; [ebp - 44] n
            @push 1.0
            @push 0.0
            @push 0.0

            vshufps xmm3, xmm7, xmm7, 0b01010101
            @push 0x80000000
            @push 0x80000000
            @push 0x80000000
            @push 0x80000000
            
            vxorps xmm3, xmm3, [esp+12]
            add esp, 16
            vdivps xmm3, xmm3, xmm2
            vshufps xmm3, xmm3, xmm3, 0b01010101
            vmovd eax, xmm3 ; sign bit is the only part that stays intact when you put raw float bytes and interpret as int
            cmp eax, 0
            jge if_tf_is_not_greater_than_0

if_tf_is_greater_than_0:
            mov dword [ebp-32], eax
            mov eax, 1 ; 1 meaning floor

if_tf_is_not_greater_than_0:
            
            ; for cube 1
            enter
            @push -100000.0 ; [ebp-4] tmin
            @push 100000.0 ; [ebp-8] tmax
            
            ; cube is in edi/esi, ro is in xmm7, rd is in xmm2
            @push 0.0 ; [ebp-12] hit_axis
            ; [edi] bmin
            ; [edi-12] bmax

            @push 1.0
            vdivss xmm3, [esp], xmm2
            add esp, 4

            vmovaps xmm4, [edi] ; f0 is bmin, f3 is bmax
            vbroadcastss xmm6, xmm7
            vsubps xmm4, xmm4, xmm6
            vbroadcastss xmm3, xmm3
            vmulss xmm4, xmm4, xmm3
            ; t1 is in f0
            ; t2 is in f3
            vbroadcastss xmm6, xmm4
            vshufps xmm5, xmm4, xmm4, 0b11111111
            vcmpss xmm3, xmm5, xmm6, 1
            @push 0
            vmovd [esp], xmm3
            cmp [esp], 0
            jne if_not_t1_greater_t2

if_t1_greater_t2:
            vshufps xmm4, xmm4, xmm4, 0b11011000
if_not_t1_greater_t2:
            add esp, 4
            
            mov dword [ebp-12], 0
            vmovd dword [ebp-4], xmm4
            vmovd dword [ebp-8], xmm5


            ; [edi-4] bmin
            ; [edi-16] bmax

            @push 1.0
            vdivss xmm3, [esp], xmm2
            vshufps xmm3, xmm3, xmm3, 0b01001011
            add esp, 4

            vmovups xmm4, [edi-4] ; f0 is bmin, f3 is bmax
            vmovaps xmm6, xmm7
            vshufps xmm6, xmm6, xmm6, 0b01010101
            vsubps xmm4, xmm4, xmm6
            vbroadcastss xmm3, xmm3
            vmulss xmm4, xmm4, xmm3
            ; t1 is in f0
            ; t2 is in f3
            vbroadcastss xmm6, xmm4
            vshufps xmm5, xmm4, xmm4, 0b11111111
            vcmpss xmm3, xmm5, xmm6, 1
            @push 0
            vmovd [esp], xmm3
            cmp [esp], 0
            jne if_not_t1_greater_t2_l2

if_t1_greater_t2_l2:
            vshufps xmm4, xmm4, xmm4, 0b11011000
if_not_t1_greater_t2_l2:
            add esp, 4

            ; YOU NEED ANOTHER CHECK HERE FOR T1 > TMIN
            ; t1 in all xmm6
            ; t2 in all xmm5
            ; tmin in [ebp-4]
            ; tmax in [ebp-8]
            ; ro in xmm7
            ; rd in xmm2
            vbroadcastss xmm3, [ebp-4]
            vcmpss xmm3, xmm6, xmm3, 1
            @push 0
            vmovd [esp], xmm3
            cmp [esp], 0

            ; AND ANOTHER HERE FOR T2 < TMAX
            
            mov dword [ebp-12], 1
            vmovd dword [ebp-4], xmm4
            vmovd dword [ebp-8], xmm5


            ; [edi-8] bmin
            ; [edi-20] bmax

            @push 1.0
            vdivss xmm3, [esp], xmm2
            vshufps xmm3, xmm3, xmm3, 0b10010011
            add esp, 4

            vmovups xmm4, [edi-8] ; f0 is bmin, f3 is bmax
            vmovaps xmm6, xmm7
            vshufps xmm6, xmm6, xmm6, 0b10101010
            vsubps xmm4, xmm4, xmm6
            vbroadcastss xmm3, xmm3
            vmulss xmm4, xmm4, xmm3
            ; t1 is in f0
            ; t2 is in f3
            vbroadcastss xmm6, xmm4
            vshufps xmm5, xmm4, xmm4, 0b11111111
            vcmpss xmm3, xmm5, xmm6, 1
            @push 0
            vmovd [esp], xmm3
            cmp [esp], 0
            jne if_not_t1_greater_t2_l3

if_t1_greater_t2_l3:
            vshufps xmm4, xmm4, xmm4, 0b11011000
if_not_t1_greater_t2_l3:
            add esp, 4

            ; YOU NEED ANOTHER CHECK HERE FOR T1 > TMIN
            ; AND ANOTHER HERE FOR T2 < TMAX
            
            mov dword [ebp-12], 2
            vmovd dword [ebp-4], xmm4
            vmovd dword [ebp-8], xmm5

            leave
            
            

            ; for cube 2
            

            add esp, 4
          inc edx
          jmp for_2_loop
          skip_for_2_loop:

        inc ecx
        jmp for_x_loop
        skip_for_x_loop:

        inc ebx
        jmp for_y_loop
        skip_for_y_loop:



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
    @push ebx
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
    @push 1 ; number of cubes
    and esp, -64

    @push -2.2
    @push 0.0
    @push -0.8
    @push -0.5999
    @push 1.6
    @push 0.8
    @push 25.5
    @push 25.5
    @push 25.5
    @push 1
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
    @push 1 ; number of cubes
    and esp, -64

    @push 0.5999
    @push 0.0
    @push -0.8
    @push 2.2
    @push 1.6
    @push 0.8
    @push 8000.0
    @push 6000.0
    @push 1000.0
    @push 2
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
