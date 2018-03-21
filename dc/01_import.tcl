set_svf LEDDC.svf

# Import Design
read_verilog {../src/CLE.v}
current_design [get_designs CLE]
link

source -echo -verbose ./CLE_DC.sdc
