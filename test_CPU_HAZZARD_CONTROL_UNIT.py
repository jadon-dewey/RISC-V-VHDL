import os

import pytest
from cocotb.binary import BinaryValue

import lib
from test_CPU_package import CPU


class CPU_HAZZARD_CONTROL_UNIT(lib.Entity):
    _package = CPU

    stage_id_select_source_1 = lib.Entity.Input_pin
    stage_id_select_source_2 = lib.Entity.Input_pin
    stage_ex_enable_read = lib.Entity.Input_pin
    stage_ex_enable_destination = lib.Entity.Input_pin
    stage_ex_select_destination = lib.Entity.Input_pin
    stage_mem_enable_read = lib.Entity.Input_pin
    stage_mem_select_destination = lib.Entity.Input_pin
    stall_branch = lib.Entity.Output_pin
    destination = lib.Entity.Output_pin

    # New ports for interrupt-driven flush
    interrupt_req                = lib.Entity.Input_pin
    flush_pipeline               = lib.Entity.Output_pin

@CPU_HAZZARD_CONTROL_UNIT.testcase
async def tb_CPU_HAZZARD_FLUSH(dut: CPU_HAZZARD_CONTROL_UNIT, trace: lib.Waveform):
    """
    Test the pipeline flush functionality:
      - When an interrupt is active, flush_pipeline should be asserted.
      - Also, if hazard conditions (stall_branch) are met, flush_pipeline should be high.
    """
    # Drive inputs so that no hazard is present.
    dut.stage_id_select_source_1.value = BinaryValue("00001")  # example register number
    dut.stage_id_select_source_2.value = BinaryValue("00010")
    dut.stage_ex_select_destination.value = BinaryValue("00011")
    dut.stage_mem_select_destination.value = BinaryValue("00100")
    dut.stage_ex_enable_read.value = BinaryValue("0")
    dut.stage_ex_enable_destination.value = BinaryValue("0")
    dut.stage_mem_enable_read.value = BinaryValue("0")
    
    # Also, set interrupt_req to '0'
    dut.interrupt_req.value = BinaryValue("0")
    
    await trace.cycle()
    # With no hazard and no interrupt, flush_pipeline should be '0'
    yield trace.check(dut.flush_pipeline, "0", "No hazard: flush_pipeline should be low.")
    
    # Now, force a hazard condition by making one of the stage_id sources equal to stage_ex_select_destination
    dut.stage_id_select_source_1.value = dut.stage_ex_select_destination.value
    dut.stage_ex_enable_destination.value = BinaryValue("1")
    
    await trace.cycle()
    # In this condition, stall_branch will be asserted and if flush_pipeline is defined as interrupt_req OR stall_branch, then flush_pipeline should be '1'.
    yield trace.check(dut.stall_branch, "1", "Hazard active: flush_pipeline should be high.")
    
    # Clear hazard inputs and drive interrupt_req.
    dut.stage_ex_enable_destination.value = BinaryValue("0")
    dut.interrupt_req.value = BinaryValue("1")
    
    await trace.cycle()
    yield trace.check(dut.flush_pipeline, "1", "Interrupt active: flush_pipeline should be high.")
    
    # Finally, clear the interrupt.
    dut.interrupt_req.value = BinaryValue("0")
    await trace.cycle()
    yield trace.check(dut.flush_pipeline, "0", "Interrupt cleared: flush_pipeline should be low.")

@pytest.mark.synthesis
def test_CPU_HAZZARD_CONTROL_UNIT_synthesis():
    CPU_HAZZARD_CONTROL_UNIT.build_vhd()
    CPU_HAZZARD_CONTROL_UNIT.build_netlistsvg()

@pytest.mark.testcases
def test_CPU_HAZZARD_CONTROL_UNIT_testcases():
    CPU_HAZZARD_CONTROL_UNIT.test_with(tb_CPU_HAZZARD_FLUSH)

if __name__ == "__main__":
    pytest.main(["-k", os.path.basename(__file__)])
