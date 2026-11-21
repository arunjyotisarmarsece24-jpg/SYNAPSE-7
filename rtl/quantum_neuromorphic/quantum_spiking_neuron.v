// ============================================================================
// Module Name: quantum_spiking_neuron
// Project:     SYNAPSE-7 (Neuromorphic-Quantum Hardware Security Engine)
// Target:      Xilinx Spartan-7 / Cadence ASIC Flow
// Description: Synthesizable Quantum Leaky Integrate-and-Fire (Q-LIF) Neuron.
//              Models qubit superposition state vector |psi> = alpha|0> + beta|1>,
//              Hamiltonian unitary rotation (Rabi drive from synaptic current),
//              Larmor phase precession, T1/T2 quantum decoherence decay,
//              and Born-rule projective quantum measurement collapse.
// ============================================================================

`timescale 1ns / 1ps

module quantum_spiking_neuron #(
    parameter DATA_WIDTH       = 16,        // Q2.14 signed fixed-point (1.0 = 16384)
    parameter DECAY_T1_SHIFT   = 5,         // T1 relaxation leak (towards ground state |0>)
    parameter DECAY_T2_SHIFT   = 4,         // T2 dephasing rate
    parameter P_TH_DEFAULT     = 16'd8192,  // Born collapse threshold: P(|1>) >= 0.50 (in Q0.14: 8192/16384 = 50%)
    parameter REFRAC_CYCLES    = 4          // Quantum dead-time post collapse
)(
    input  wire                             clk,
    input  wire                             rst_n,
    input  wire                             enable,          // Timestep clock enable
    input  wire signed [DATA_WIDTH-1:0]     syn_current,     // Synaptic driving current (Rabi frequency drive)
    input  wire signed [DATA_WIDTH-1:0]     detuning_delta,  // Detuning / bias control (Z-axis rotation)
    input  wire [7:0]                       entropy_noise,   // TRNG entropy for stochastic quantum collapse
    input  wire                             stochastic_mode, // 0: deterministic P_th, 1: Born stochastic sampling
    input  wire [15:0]                      p_th_tune,       // Dynamically tunable firing probability threshold
    
    // Quantum State & Telemetry Outputs
    output reg                              q_spike_out,     // Quantum collapse firing event
    output wire [DATA_WIDTH-1:0]            prob_one_out,    // Live Born rule probability P(|1>) = |beta|^2
    output wire signed [DATA_WIDTH-1:0]     bloch_z_out,     // Expectation value <sigma_z> = |alpha|^2 - |beta|^2
    output wire signed [DATA_WIDTH-1:0]     coherence_out    // Quantum superposition coherence measure
);

    // Qubit state representation: |psi> = (alpha_r + i*alpha_i)|0> + (beta_r + i*beta_i)|1>
    // Initialized to pure ground state |0>: alpha_r = 1.0 (16384), all other components = 0
    localparam signed [DATA_WIDTH-1:0] ONE_FP  = 16'sd16384;
    localparam signed [DATA_WIDTH-1:0] ZERO_FP = 16'sd0;

    reg signed [DATA_WIDTH-1:0] alpha_r;
    reg signed [DATA_WIDTH-1:0] alpha_i;
    reg signed [DATA_WIDTH-1:0] beta_r;
    reg signed [DATA_WIDTH-1:0] beta_i;
    reg [3:0]                   refrac_cnt;

    initial begin
        alpha_r     = ONE_FP;
        alpha_i     = ZERO_FP;
        beta_r      = ZERO_FP;
        beta_i      = ZERO_FP;
        q_spike_out = 1'b0;
        refrac_cnt  = 4'd0;
    end

    // Active threshold selection
    wire [15:0] active_p_th = (p_th_tune == 16'd0) ? P_TH_DEFAULT : p_th_tune;

    // ------------------------------------------------------------------------
    // Readout from Registered Qubit State (Guarantees Zero Combinational Loops)
    // ------------------------------------------------------------------------
    wire [31:0] br_sq = beta_r * beta_r;
    wire [31:0] bi_sq = beta_i * beta_i;
    wire [31:0] sum_beta_sq = br_sq + bi_sq;
    wire [15:0] p_one = sum_beta_sq[29:14]; // Normalized to Q0.14 [0, 16384]

    wire [31:0] ar_sq = alpha_r * alpha_r;
    wire [31:0] ai_sq = alpha_i * alpha_i;
    wire [31:0] sum_alpha_sq = ar_sq + ai_sq;
    wire [15:0] p_zero = sum_alpha_sq[29:14];

    assign prob_one_out  = p_one;
    assign bloch_z_out   = $signed(p_zero) - $signed(p_one); // <sigma_z> in [-1.0, +1.0]
    assign coherence_out = (alpha_r * beta_r) >>> 13;        // 2 * Re(alpha * beta)

    // ------------------------------------------------------------------------
    // Unitary Time Evolution & Hamiltonian Integration:
    // H = (hbar * Omega / 2) * sigma_x + (hbar * Delta / 2) * sigma_z
    // d(alpha_r)/dt = + (Delta/2)*alpha_i + (Omega/2)*beta_i
    // d(alpha_i)/dt = - (Delta/2)*alpha_r - (Omega/2)*beta_r
    // d(beta_r)/dt  = - (Delta/2)*beta_i  + (Omega/2)*alpha_i
    // d(beta_i)/dt  = + (Delta/2)*beta_r  - (Omega/2)*alpha_r
    // ------------------------------------------------------------------------
    wire signed [DATA_WIDTH-1:0] omega = syn_current;
    wire signed [DATA_WIDTH-1:0] delta = detuning_delta;

    // Numerical integration scaling
    wire signed [DATA_WIDTH-1:0] d_ar = (($signed(delta) * $signed(alpha_i)) + ($signed(omega) * $signed(beta_i))) >>> 6;
    wire signed [DATA_WIDTH-1:0] d_ai = ((-$signed(delta) * $signed(alpha_r)) - ($signed(omega) * $signed(beta_r))) >>> 6;
    wire signed [DATA_WIDTH-1:0] d_br = ((-$signed(delta) * $signed(beta_i))  + ($signed(omega) * $signed(alpha_i))) >>> 6;
    wire signed [DATA_WIDTH-1:0] d_bi = (($signed(delta) * $signed(beta_r))   - ($signed(omega) * $signed(alpha_r))) >>> 6;

    // Open Quantum System Decoherence:
    // T1 relaxation: beta leaks to zero, alpha relaxes to ONE_FP
    wire signed [DATA_WIDTH-1:0] beta_r_leak = beta_r >>> DECAY_T1_SHIFT;
    wire signed [DATA_WIDTH-1:0] beta_i_leak = beta_i >>> DECAY_T1_SHIFT;
    wire signed [DATA_WIDTH-1:0] alpha_r_pull = (ONE_FP - alpha_r) >>> DECAY_T1_SHIFT;

    // T2 dephasing: decays off-diagonal components
    wire signed [DATA_WIDTH-1:0] alpha_i_dephase = alpha_i >>> DECAY_T2_SHIFT;

    // Candidate next quantum states before collapse
    wire signed [DATA_WIDTH-1:0] next_ar = alpha_r + d_ar + alpha_r_pull;
    wire signed [DATA_WIDTH-1:0] next_ai = alpha_i + d_ai - alpha_i_dephase;
    wire signed [DATA_WIDTH-1:0] next_br = beta_r  + d_br - beta_r_leak;
    wire signed [DATA_WIDTH-1:0] next_bi = beta_i  + d_bi - beta_i_leak;

    // Stochastic vs Deterministic Collapse Criterion
    wire [15:0] random_threshold = {2'b00, entropy_noise, 6'd0};
    wire trigger_collapse = stochastic_mode ? 
                            (p_one > random_threshold) : 
                            (p_one >= active_p_th);

    // ------------------------------------------------------------------------
    // Sequential State Update & Wavefunction Collapse
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alpha_r     <= ONE_FP;
            alpha_i     <= ZERO_FP;
            beta_r      <= ZERO_FP;
            beta_i      <= ZERO_FP;
            q_spike_out <= 1'b0;
            refrac_cnt  <= 4'd0;
        end else if (enable) begin
            if (refrac_cnt > 4'd0) begin
                // In quantum refractory period: clamped to ground state |0>
                alpha_r     <= ONE_FP;
                alpha_i     <= ZERO_FP;
                beta_r      <= ZERO_FP;
                beta_i      <= ZERO_FP;
                q_spike_out <= 1'b0;
                refrac_cnt  <= refrac_cnt - 1'b1;
            end else if (trigger_collapse) begin
                // BORN MEASUREMENT COLLAPSE: Emit Q-Spike and collapse state to |0>
                q_spike_out <= 1'b1;
                alpha_r     <= ONE_FP;
                alpha_i     <= ZERO_FP;
                beta_r      <= ZERO_FP;
                beta_i      <= ZERO_FP;
                refrac_cnt  <= REFRAC_CYCLES[3:0];
            end else begin
                // Continuous unitary Hamiltonian evolution with bounds clamping
                q_spike_out <= 1'b0;
                // Clamp alpha_r to [-16384, +16384]
                if (next_ar > ONE_FP)
                    alpha_r <= ONE_FP;
                else if (next_ar < -ONE_FP)
                    alpha_r <= -ONE_FP;
                else
                    alpha_r <= next_ar;

                alpha_i <= next_ai;

                if (next_br > ONE_FP)
                    beta_r <= ONE_FP;
                else if (next_br < -ONE_FP)
                    beta_r <= -ONE_FP;
                else
                    beta_r <= next_br;

                beta_i <= next_bi;
            end
        end else begin
            q_spike_out <= 1'b0;
        end
    end

endmodule
