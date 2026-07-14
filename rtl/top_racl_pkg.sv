// top_racl_pkg.sv (Dummy for iverilog simulation)
package top_racl_pkg;
  typedef logic [3:0] racl_policy_sel_t;
  typedef logic [3:0] racl_role_t;
  typedef logic [15:0] racl_role_vec_t;
  typedef logic [7:0] ctn_uid_t;

  typedef struct packed {
    logic [15:0] read_perm;
    logic [15:0] write_perm;
  } racl_policy_t;

  typedef racl_policy_t racl_policy_vec_t [16];

  typedef struct packed {
    logic valid;
    logic [31:0] request_address;
    racl_role_t racl_role;
    logic overflow;
    ctn_uid_t ctn_uid;
    logic read_access;
  } racl_error_log_t;

  function automatic racl_role_t tlul_extract_racl_role_bits(logic [31:0] rsvd);
    return '0;
  endfunction

  function automatic ctn_uid_t tlul_extract_ctn_uid_bits(logic [31:0] rsvd);
    return '0;
  endfunction
endpackage
