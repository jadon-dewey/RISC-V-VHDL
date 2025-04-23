import warnings
# Catch the warning so the testing/validation process can run smoothly
warnings.filterwarnings(
    "ignore",
    message=".*Python runners and associated APIs are an experimental feature and subject to change.*", # Insert a try-and-catch statement
    category=UserWarning
)

import pytest #import pytest to validate vhdl code with python test cases
import random # import random to generate random values for stress testing
from cocotb.binary import BinaryValue # import cocotb for testbench validation
from cocotb.triggers import RisingEdge # import cocotb for testbench validation tools to access internal signals in the interruption unit

import lib # import lib to declare signals from the Interrupt unit

class INTERRUPT_UNIT(lib.Entity):
    # Input signals
    clk = lib.Entity.Input_pin # Clock
    reset_n = lib.Entity.Input_pin # Reset signal
    # Interrupt enable signals
    mie = lib.Entity.Input_pin   # Global interrupt enable
    msie = lib.Entity.Input_pin  # Software interrupt enable
    mtie = lib.Entity.Input_pin  # Timer interrupt enable
    meie = lib.Entity.Input_pin  # External interrupt enable
    # Interrupt pending signals (inputs)
    msip = lib.Entity.Input_pin  # Software interrupt pending
    mtip = lib.Entity.Input_pin  # Timer interrupt pending
    meip = lib.Entity.Input_pin  # External interrupt pending
    # Acknowledge signal from the CPU
    acknowledge = lib.Entity.Input_pin
    # Vector base address from mtvec register
    mtvec_base = lib.Entity.Input_pin  # MTVEC base address
    vectored_mode = lib.Entity.Input_pin  # Indicates if vectored mode is enabled
    # Output signals
    interrupt_ack = lib.Entity.Output_pin # Checks if the interrupt_out signal is deasserted after the interrupt is acknowledges 
    # this is important because the interrupt_out signal may become asserted again later if other interrupts are pending
    interrupt_out = lib.Entity.Output_pin # interrupt_out signal, this wil be sent to the CPU
    interrupt_address = lib.Entity.Output_pin # interrupt address signal will be sent to the CPU to branch the Program Counter (PC)
    # Mask control
    mask_write_enable = lib.Entity.Input_pin
    mask_write_data = lib.Entity.Input_pin

@INTERRUPT_UNIT.testcase
async def tb_INTERRUPT_UNIT_no_interrupts(dut: INTERRUPT_UNIT, trace: lib.Waveform):
    """Test Case 1: No interrupts enabled or pending"""
    # Initialize inputs
    dut.reset_n.value = BinaryValue("1")
    dut.mie.value = BinaryValue("0")
    dut.msie.value = BinaryValue("0")
    dut.mtie.value = BinaryValue("0")
    dut.meie.value = BinaryValue("0")
    dut.msip.value = BinaryValue("0")
    dut.mtip.value = BinaryValue("0")
    dut.meip.value = BinaryValue("0")
    dut.mtvec_base.value = BinaryValue(format(0x80000000, '032b'))
    dut.vectored_mode.value = BinaryValue("0")
    dut.acknowledge.value = BinaryValue("0")
    dut.mask_write_enable.value = BinaryValue("0")
    dut.mask_write_data.value = BinaryValue("000")

    # Wait for a few clock cycles
    await trace.cycle()
    await trace.cycle()

    # Check that interrupt_out remains '0'
    yield trace.check(dut.interrupt_out, "0", "interrupt_out should remain deasserted")

@INTERRUPT_UNIT.testcase
async def tb_INTERRUPT_UNIT_sw_interrupt_not_enabled(dut: INTERRUPT_UNIT, trace: lib.Waveform):
    """Test Case 2: Software interrupt pending but not enabled"""
    # Set inputs
    dut.msip.value = BinaryValue("1")  # Software interrupt pending
    dut.msie.value = BinaryValue("0")  # Software interrupt not enabled
    dut.mie.value = BinaryValue("1")   # Global interrupt enable
    dut.acknowledge.value = BinaryValue("0")

    # Wait for a few clock cycles
    for _ in range(4):
        await trace.cycle()

    # Check that interrupt_out remains '0'
    yield trace.check(dut.interrupt_out, "0", "interrupt_out should not assert when software interrupt is not enabled")

@INTERRUPT_UNIT.testcase
async def tb_INTERRUPT_UNIT_sw_interrupt_enabled(dut: INTERRUPT_UNIT, trace: lib.Waveform):
    """Test Case 3: Software interrupt enabled and pending"""

     # Reset the DUT
    dut.reset_n.value = BinaryValue("0")
    # Wait for a few clock cycles
    for _ in range(5):
        await trace.cycle()
    dut.reset_n.value = BinaryValue("1")
    await trace.cycle()

    # Enable software interrupt
    dut.mie.value = BinaryValue("1")   # Global interrupt enable
    dut.msie.value = BinaryValue("0")  # Enable software interrupt
    dut.msip.value = BinaryValue("0")  # Software interrupt pending
     # Wait for a few clock cycles
    for _ in range(2):
        await trace.cycle()
    dut.msie.value = BinaryValue("1") # Software interrupt enabled
    dut.msip.value = BinaryValue("1")  # Software interrupt pending
    dut.acknowledge.value = BinaryValue("0") #acknowledge defaults to zero with no ISR sent

    # Wait for a few clock cycles
    for _ in range(3):
        await trace.cycle()

    # Check if interrupt_out is asserted
    yield trace.check(dut.interrupt_out, "1", "interrupt_out should assert for enabled software interrupt")

    # Simulate CPU acknowledging the interrupt
    dut.acknowledge.value = BinaryValue("1")
    await trace.cycle()
    dut.acknowledge.value = BinaryValue("0")
    await trace.cycle()
    await trace.cycle()

    # Check that interrupt_out is deasserted after acknowledgment
    yield trace.check(dut.interrupt_out, "0", "interrupt_out should deassert after acknowledgment")

@INTERRUPT_UNIT.testcase
async def tb_INTERRUPT_UNIT_clear_sw_interrupt(dut: INTERRUPT_UNIT, trace: lib.Waveform):
    """Test Case 4: Clear software interrupt pending"""
    # Apply reset
    dut.reset_n.value = BinaryValue("0")
    for _ in range(5):
        await trace.cycle()
    dut.reset_n.value = BinaryValue("1")
    await trace.cycle()

    # Enable software interrupt
    dut.mie.value = BinaryValue("1")   # Global interrupt enable
    dut.msie.value = BinaryValue("0")  # Enable software interrupt
    dut.msip.value = BinaryValue("0")  # Software interrupt pending
     # Wait for a few clock cycles
    for _ in range(2):
        await trace.cycle()
    dut.msie.value = BinaryValue("1") # Software interrupt enabled
    dut.msip.value = BinaryValue("1")  # Software interrupt pending
    dut.acknowledge.value = BinaryValue("0") #acknowledge defaults to zero with no ISR sent

    # Wait for a few clock cycles
    for _ in range(2):
        await trace.cycle()

    # Clear software interrupt pending
    dut.msip.value = BinaryValue("0")  # Clear software interrupt pending
    dut.msie.value = BinaryValue("0")  # Clear software enable

    await trace.cycle()
    # Check that interrupt_out is deasserted
    yield trace.check(dut.interrupt_out, "1", "interrupt_out should still be asserted if the interrupt was not ackowledged by the CPU")

    # Simulate CPU acknowledging the interrupt
    dut.acknowledge.value = BinaryValue("1")
    await trace.cycle()
    dut.acknowledge.value = BinaryValue("0")

    # Wait for a few clock cycles
    for _ in range(4):
        await trace.cycle()

    # Check that interrupt_out is deasserted
    yield trace.check(dut.interrupt_out, "0", "interrupt_out should deassert after software interrupt was cleared")

    # Check if software interrupt does not process if msie is cleared
    
    dut.msip.value = BinaryValue("1")  # Software interrupt pending
    dut.acknowledge.value = BinaryValue("0") #acknowledge defaults to zero with no ISR sent

    # Wait for a few clock cycles
    for _ in range(2):
        await trace.cycle()

    # Clear software interrupt pending
    dut.msip.value = BinaryValue("0")  # Clear software interrupt pending

    await trace.cycle()
    # Check that interrupt_out is deasserted
    yield trace.check(dut.interrupt_out, "0", "interrupt_out should still be deasserted if misp is 0")


@INTERRUPT_UNIT.testcase
async def tb_INTERRUPT_UNIT_timer_interrupt(dut: INTERRUPT_UNIT, trace: lib.Waveform):
    """Test Case 5: Timer interrupt pending and enabled"""
    # Reset the DUT
    dut.reset_n.value = BinaryValue("0")
    # Wait for a few clock cycles
    for _ in range(5):
        await trace.cycle()
    dut.reset_n.value = BinaryValue("1")
    await trace.cycle()

    # Timer interrupt pending and enabled
    dut.msie.value = BinaryValue("0")  # Disable software interrupt
    dut.mtie.value = BinaryValue("0")  # Enable Timer interrupt
    dut.mtip.value = BinaryValue("0")  # Timer interrupt pending
     # Wait for a few clock cycles
    for _ in range(2):
        await trace.cycle()
    dut.mtie.value = BinaryValue("1")  # Enable Timer interrupt
    dut.mtip.value = BinaryValue("1")  # Timer interrupt pending
    dut.mie.value = BinaryValue("1")   # Global interrupt enable
    dut.acknowledge.value = BinaryValue("0")

    # Wait for a few clock cycles
    for _ in range(5):
        await trace.cycle()

    # Check if interrupt_out is asserted
    yield trace.check(dut.interrupt_out, "1", "interrupt_out should assert for enabled timer interrupt")

    # Simulate CPU acknowledging the interrupt
    dut.acknowledge.value = BinaryValue("1")
    await trace.cycle()
    dut.acknowledge.value = BinaryValue("0")
    await trace.cycle()
    await trace.cycle()

    # Check that interrupt_out is deasserted after acknowledgment
    yield trace.check(dut.interrupt_out, "0", "interrupt_out should deassert after acknowledgment")

@INTERRUPT_UNIT.testcase
async def tb_INTERRUPT_UNIT_external_interrupt(dut: INTERRUPT_UNIT, trace: lib.Waveform):
    """Test Case 6: External interrupt pending and enabled"""

    # Reset the DUT
    dut.reset_n.value = BinaryValue("0")
    # Wait for a few clock cycles
    for _ in range(5):
        await trace.cycle()
    dut.reset_n.value = BinaryValue("1")
    await trace.cycle()

    # Ensure timer interrupt is not pending
    dut.mtip.value = BinaryValue("0")
    dut.mtie.value = BinaryValue("0")
    # Enable external interrupt
    dut.meie.value = BinaryValue("0")  # Enable External interrupt
    dut.meip.value = BinaryValue("0")  # External interrupt pending
     # Wait for a few clock cycles
    for _ in range(2):
        await trace.cycle()
    dut.meie.value = BinaryValue("1")  # Enable External interrupt
    dut.meip.value = BinaryValue("1")  # External interrupt pending
    dut.mie.value = BinaryValue("1")   # Global interrupt enable
    dut.acknowledge.value = BinaryValue("0")

    # Wait for a few clock cycles
    for _ in range(5):
        await trace.cycle()

    # Check if interrupt_out is asserted
    yield trace.check(dut.interrupt_out, "1", "interrupt_out should assert for enabled external interrupt")

    # Simulate CPU acknowledging the interrupt
    dut.acknowledge.value = BinaryValue("1")
    await trace.cycle()
    dut.acknowledge.value = BinaryValue("0")
    await trace.cycle()
    await trace.cycle()

    # Check that interrupt_out is deasserted after acknowledgment
    yield trace.check(dut.interrupt_out, "0", "interrupt_out should deassert after acknowledgment")

    # Wait for a few clock cycles
    for _ in range(5):
        await trace.cycle()
        
@INTERRUPT_UNIT.testcase
async def tb_INTERRUPT_UNIT_multiple_interrupts(dut: INTERRUPT_UNIT, trace: lib.Waveform):
    """Test Case 7: Multiple interrupts pending (software and timer)"""
    # Reset the DUT
    dut.reset_n.value = BinaryValue("0")
    # Wait for a few clock cycles
    for _ in range(5):
        await trace.cycle()
    dut.reset_n.value = BinaryValue("1")
    await trace.cycle()

    # Enable and set pending interrupts
    dut.msie.value = BinaryValue("0")  # Enable software interrupt
    dut.msip.value = BinaryValue("0")  # Software interrupt pending
    dut.mtie.value = BinaryValue("0")  # Enable timer interrupt
    dut.mtip.value = BinaryValue("0")  # Timer interrupt pending

    for _ in range(2):
        await trace.cycle()

    dut.msie.value = BinaryValue("1")  # Enable software interrupt
    dut.msip.value = BinaryValue("1")  # Software interrupt pending
    dut.mtie.value = BinaryValue("1")  # Enable timer interrupt
    dut.mtip.value = BinaryValue("1")  # Timer interrupt pending
    dut.mie.value = BinaryValue("1")   # Global interrupt enable
    dut.acknowledge.value = BinaryValue("0")

    # Wait for a few clock cycles
    for _ in range(5):
        await trace.cycle()

    # Check if interrupt_out is asserted
    yield trace.check(dut.interrupt_out, "1", "interrupt_out should assert for multiple pending interrupts")

@INTERRUPT_UNIT.testcase
async def tb_INTERRUPT_UNIT_vectored_mode(dut: INTERRUPT_UNIT, trace: lib.Waveform):
    """Test Case 8: Vectored mode enabled and software interrupt triggered"""
    # Reset the DUT
    dut.reset_n.value = BinaryValue("0")
    # Wait for a few clock cycles
    for _ in range(5):
        await trace.cycle()
    dut.reset_n.value = BinaryValue("1")
    await trace.cycle()

    # Enable vectored mode
    dut.vectored_mode.value = BinaryValue("1")

    dut.msip.value = BinaryValue("0")  # Software interrupt pending
    dut.msie.value = BinaryValue("0")  # Enable software interrupt

    for _ in range(2):
        await trace.cycle()

    dut.msip.value = BinaryValue("1")  # Software interrupt pending
    dut.msie.value = BinaryValue("1")  # Enable software interrupt
    dut.mie.value = BinaryValue("1")   # Global interrupt enable
    dut.acknowledge.value = BinaryValue("0")
    dut.mtvec_base.value = BinaryValue(format(0x80000000, '032b'))

    # Wait for a few clock cycles
    for _ in range(5):
        await trace.cycle()

    # Expected address calculation
    expected_address = 0x80000000 + (3 * 4)  # Cause code 3 for software interrupt
    expected_address_bin = format(expected_address, '032b')

    # Check that the interrupt address matches expected value
    yield trace.check(dut.interrupt_address, expected_address_bin, "Incorrect interrupt_address in vectored mode")

@INTERRUPT_UNIT.testcase
async def tb_INTERRUPT_UNIT_global_interrupt_disable_enable(dut: INTERRUPT_UNIT, trace: lib.Waveform):
    """Test Case 9: Global interrupt disable and enable"""
    # Reset the DUT
    dut.reset_n.value = BinaryValue("0")
    # Wait for a few clock cycles
    for _ in range(5):
        await trace.cycle()
    dut.reset_n.value = BinaryValue("1")
    await trace.cycle()

    dut.mie.value = BinaryValue("0")  # Disable global interrupts

    dut.msip.value = BinaryValue("0")  # Software interrupt pending
    dut.msie.value = BinaryValue("0")  # Enable software interrupt

    for _ in range(2):
        await trace.cycle()

    dut.msip.value = BinaryValue("1")  # Software interrupt pending
    dut.msie.value = BinaryValue("1")  # Enable software interrupt

    # Wait for a few clock cycles
    for _ in range(4):
        await trace.cycle()

    # Check if interrupt_out is deasserted
    yield trace.check(dut.interrupt_out, "0", "interrupt_out should not assert when global interrupts are disabled")

    # Re-enable global interrupt
    dut.mie.value = BinaryValue("1")  # Re-enable global interrupts

    # Wait for a few clock cycles
    for _ in range(4):
        await trace.cycle()

    # Check if interrupt_out is asserted
    yield trace.check(dut.interrupt_out, "1", "interrupt_out should assert after global interrupt re-enable")

@INTERRUPT_UNIT.testcase
async def tb_INTERRUPT_UNIT_change_mtvec_base(dut: INTERRUPT_UNIT, trace: lib.Waveform):
    """Test Case 10: Change mtvec_base"""
    # Reset the DUT
    dut.reset_n.value = BinaryValue("0")
    # Wait for a few clock cycles
    for _ in range(5):
        await trace.cycle()
    dut.reset_n.value = BinaryValue("1")
    await trace.cycle()

    dut.mtvec_base.value = BinaryValue(format(0x80001000, '032b'))  # Change mtvec base address

    dut.mie.value = BinaryValue("1")   # Global interrupt enable
    dut.msie.value = BinaryValue("0")  # Enable software interrupt
    dut.msip.value = BinaryValue("0")  # Software interrupt pending
     # Wait for a few clock cycles
    for _ in range(2):
        await trace.cycle()
    dut.msie.value = BinaryValue("1")
    dut.msip.value = BinaryValue("1")  # Software interrupt pending
    
    # Wait for a few clock cycles
    for _ in range(4):
        await trace.cycle()

    # Check that the new address is correctly reflected
    expected_address_bin = format(0x80001000, '032b')
    yield trace.check(dut.interrupt_address, expected_address_bin, "mtvec_base change not reflected in interrupt address")

@INTERRUPT_UNIT.testcase
async def tb_INTERRUPT_UNIT_reset_unit(dut: INTERRUPT_UNIT, trace: lib.Waveform):
    """Test Case 11: Reset the unit"""
    dut.reset_n.value = BinaryValue("0")  # Assert reset
    await trace.cycle()
    dut.reset_n.value = BinaryValue("1")  # Deassert reset
    await trace.cycle()

    # Wait for a few clock cycles
    for _ in range(4):
        await trace.cycle()

    # Check if interrupt_out is deasserted
    yield trace.check(dut.interrupt_out, "0", "interrupt_out should be deasserted after reset")

@INTERRUPT_UNIT.testcase
async def tb_INTERRUPT_UNIT_multiple_sw_interrupts(dut: INTERRUPT_UNIT, trace: lib.Waveform):
    """Test Case 12: Multiple software interrupts from the same source"""
    # Reset the DUT
    dut.reset_n.value = BinaryValue("0")
    # Wait for a few clock cycles
    for _ in range(5):
        await trace.cycle()
    dut.reset_n.value = BinaryValue("1")
    await trace.cycle()

    # Access the internal signal
    # pending_counts = dut.interrupt_pending_counts
    # Initialize signals
    dut.msie.value = BinaryValue("0")
    dut.msip.value = BinaryValue("0")
    for _ in range(2):
        await trace.cycle()
    dut.msie.value = BinaryValue("1")  # Enable software interrupt
    dut.mie.value = BinaryValue("1")   # Global interrupt enable
    dut.vectored_mode.value = BinaryValue("1")
    dut.acknowledge.value = BinaryValue("0")

    # First software interrupt pending
    dut.msip.value = BinaryValue("1")
    await trace.cycle()
    dut.msip.value = BinaryValue("0")  # Deassert if edge-triggered

    # Wait and check interrupt_out
    for _ in range(2):
        await trace.cycle()
    # yield trace.check(dut.interrupt_pending_counts(0), "1", "The vector interrupt_pending_counts should be appended once")
    yield trace.check(dut.interrupt_out, "1", "interrupt_out should assert for first software interrupt")

    # Second software interrupt pending before first is acknowledged
    dut.msip.value = BinaryValue("1")
    await trace.cycle()
    dut.msip.value = BinaryValue("0")

    # Simulate CPU acknowledging the first interrupt
    dut.acknowledge.value = BinaryValue("1")
    await trace.cycle()
    dut.acknowledge.value = BinaryValue("0")

    # Wait and check interrupt_out remains asserted
    for _ in range(2):
        await trace.cycle()
    yield trace.check(dut.interrupt_out, "1", "interrupt_out should remain asserted due to pending interrupts")

    # Simulate CPU acknowledging the second interrupt
    dut.acknowledge.value = BinaryValue("1")
    await trace.cycle()
    dut.acknowledge.value = BinaryValue("0")

    # Wait to ensure interrupt_out is deasserted
    for _ in range(2):
        await trace.cycle()
    yield trace.check(dut.interrupt_out, "0", "interrupt_out should deassert after second acknowledgment")

@INTERRUPT_UNIT.testcase
async def tb_INTERRUPT_UNIT_simultaneous_interrupts(dut: INTERRUPT_UNIT, trace: lib.Waveform):
    """Test Case 13: Simultaneous interrupts from different sources"""
    # Reset the DUT
    dut.reset_n.value = BinaryValue("0")
    # Wait for a few clock cycles
    for _ in range(5):
        await trace.cycle()
    dut.reset_n.value = BinaryValue("1")
    await trace.cycle()
    
    # Initialize signals
    dut.msie.value = BinaryValue("0")  # Reset software interrupt
    dut.mtie.value = BinaryValue("0")  # Reset timer interrupt
    dut.meie.value = BinaryValue("0")  # Reset external interrupt
    dut.msip.value = BinaryValue("0")  # Reset Software interrupt pending
    dut.mtip.value = BinaryValue("0")  # Reset Timer interrupt pending
    dut.meip.value = BinaryValue("0")  # Reset External interrupt pending
    for _ in range(2):
        await trace.cycle()
    dut.msie.value = BinaryValue("1")  # Enable software interrupt
    dut.mtie.value = BinaryValue("1")  # Enable timer interrupt
    dut.meie.value = BinaryValue("1")  # Enable external interrupt
    dut.mie.value = BinaryValue("1")   # Global interrupt enable
    dut.vectored_mode.value = BinaryValue("1")
    dut.acknowledge.value = BinaryValue("0")
    dut.mtvec_base.value = BinaryValue(format(0x80000000, '032b'))

    # Set pending interrupts simultaneously
    dut.msip.value = BinaryValue("1")  # Software interrupt pending
    dut.mtip.value = BinaryValue("1")  # Timer interrupt pending
    dut.meip.value = BinaryValue("1")  # External interrupt pending
    await trace.cycle()
    # Deassert if edge-triggered
    dut.msip.value = BinaryValue("0")
    dut.mtip.value = BinaryValue("0")
    dut.meip.value = BinaryValue("0")

    # Wait and check interrupt_out
    for _ in range(3):
        await trace.cycle()
    yield trace.check(dut.interrupt_out, "1", "interrupt_out should assert for simultaneous interrupts")

    # Check that the highest priority interrupt is serviced first (software interrupt)
    expected_cause = 3  # Cause code for software interrupt
    expected_address = 0x80000000 + (expected_cause * 4)
    expected_address_bin = format(expected_address, '032b')

    # Check interrupt_address
    yield trace.check(dut.interrupt_address, expected_address_bin, "Highest priority interrupt not serviced first")

    # Simulate CPU acknowledging the first interrupt
    dut.acknowledge.value = BinaryValue("1")
    await trace.cycle()
    dut.acknowledge.value = BinaryValue("0")

    # Wait and check that the next highest priority interrupt is serviced (timer interrupt)
    for _ in range(3):
        await trace.cycle()
    yield trace.check(dut.interrupt_out, "1", "interrupt_out should remain asserted due to pending interrupts")

    expected_cause = 7  # Cause code for timer interrupt
    expected_address = 0x80000000 + (expected_cause * 4)
    expected_address_bin = format(expected_address, '032b')

    yield trace.check(dut.interrupt_address, expected_address_bin, "Next highest priority interrupt not serviced")

    # Simulate CPU acknowledging the second interrupt
    dut.acknowledge.value = BinaryValue("1")
    await trace.cycle()
    dut.acknowledge.value = BinaryValue("0")

    # Wait and check for the third interrupt (external interrupt)
    for _ in range(3):
        await trace.cycle()
    yield trace.check(dut.interrupt_out, "1", "interrupt_out should remain asserted due to pending interrupts")

    expected_cause = 11  # Cause code for external interrupt
    expected_address = 0x80000000 + (expected_cause * 4)
    expected_address_bin = format(expected_address, '032b')

    yield trace.check(dut.interrupt_address, expected_address_bin, "Third interrupt not serviced")

    # Simulate CPU acknowledging the third interrupt
    dut.acknowledge.value = BinaryValue("1")
    await trace.cycle()
    dut.acknowledge.value = BinaryValue("0")

    # Wait and check that no interrupts are pending
    for _ in range(2):
        await trace.cycle()
    yield trace.check(dut.interrupt_out, "0", "interrupt_out should deassert after all acknowledgments")

@INTERRUPT_UNIT.testcase
async def tb_INTERRUPT_UNIT_interrupt_masking(dut: INTERRUPT_UNIT, trace: lib.Waveform):
    """Test Case 14: Interrupt Masking"""

    # Verify that a masked interrupt does not trigger an output,but when unmasked the interrupt is correctly serviced.

    # Reset DUT
    dut.reset_n.value = BinaryValue("0")
    for _ in range(3):
        await trace.cycle()
    dut.reset_n.value = BinaryValue("1")
    await trace.cycle()

    # Set base address and enable vectored mode.
    dut.mtvec_base.value = BinaryValue(format(0x80000000, '032b'))
    dut.vectored_mode.value = BinaryValue("1")

    # Enable global interrupts and both software and timer interrupts.
    dut.mie.value = BinaryValue("1")
    dut.msie.value = BinaryValue("1")
    dut.mtie.value = BinaryValue("1")
    dut.meie.value = BinaryValue("0")  # Not used in this test

    # Start with no interrupts pending and no mask.
    dut.msip.value = BinaryValue("0")
    dut.mtip.value = BinaryValue("0")
    dut.mask_write_enable.value = BinaryValue("0")
    dut.mask_write_data.value = BinaryValue("000")  # Unmasked
    dut.acknowledge.value = BinaryValue("0") # No acknowledged interrupts currently

    await trace.cycle()

    # Now, mask the software interrupt (bit 0) via the mask interface.
    dut.mask_write_enable.value = BinaryValue("1")
    dut.mask_write_data.value = BinaryValue("001")  # Bit0=1 masks msip; others unmasked
    await trace.cycle()

    # Trigger only the software interrupt.
    dut.msip.value = BinaryValue("1")
    await trace.cycle()
    dut.msip.value = BinaryValue("0")
    await trace.cycle()

    # With msip masked, interrupt_out should remain deasserted.
    yield trace.check(dut.interrupt_out, "0",
                      "interrupt_out should not assert when the software interrupt is masked")

    # Now, unmask the software interrupt.
    dut.mask_write_enable.value = BinaryValue("1")
    dut.mask_write_data.value = BinaryValue("000")  # Unmask all interrupts
    await trace.cycle()

    # Trigger the software interrupt again.
    dut.msip.value = BinaryValue("1")
    await trace.cycle()
    dut.msip.value = BinaryValue("0")
    await trace.cycle()

    # Now, interrupt_out should assert.
    yield trace.check(dut.interrupt_out, "1",
                      "interrupt_out should assert when the software interrupt is unmasked")
    
    # Simulate CPU acknowledgment.
    dut.acknowledge.value = BinaryValue("1")
    await trace.cycle()
    await trace.cycle()
    dut.acknowledge.value = BinaryValue("0")
    await trace.cycle()
    await trace.cycle()

    yield trace.check(dut.interrupt_out, "0",
                      "interrupt_out should deassert after acknowledgment")

@INTERRUPT_UNIT.testcase
async def tb_INTERRUPT_UNIT_two_level_priority(dut: INTERRUPT_UNIT, trace: lib.Waveform):
    """Test Case 15: Two‑Level Priority Encoder"""
    # Verify that when both the software and timer interrupts are pending, the encoder selects the software interrupt (msip) first, and after
    # acknowledgment, selects the timer interrupt (mtip).
    
    # Reset DUT
    dut.reset_n.value = BinaryValue("0")
    for _ in range(3):
        await trace.cycle()
    dut.reset_n.value = BinaryValue("1")
    await trace.cycle()

    # Initial states for the pending and acknowledge signals
    dut.msip.value = BinaryValue("0")
    dut.mtip.value = BinaryValue("0")
    dut.acknowledge.value = BinaryValue("0")

    # Set base address and enable vectored mode.
    dut.mtvec_base.value = BinaryValue(format(0x80000000, '032b'))
    dut.vectored_mode.value = BinaryValue("1")

    # Enable global interrupts and both software and timer interrupts.
    dut.mie.value = BinaryValue("1")
    dut.msie.value = BinaryValue("1")
    dut.mtie.value = BinaryValue("1")
    dut.meie.value = BinaryValue("0")  # Not used in this test

    # Ensure no interrupts are masked.
    dut.mask_write_enable.value = BinaryValue("1")
    dut.mask_write_data.value = BinaryValue("000")
    await trace.cycle()

    # Trigger both software and timer interrupts simultaneously.
    dut.msip.value = BinaryValue("1")
    dut.mtip.value = BinaryValue("1")
    await trace.cycle()
    dut.msip.value = BinaryValue("0")
    dut.mtip.value = BinaryValue("0")
    await trace.cycle()
    await trace.cycle()

    # Initially, the two-level priority (round-robin) should select the software interrupt.
    # Expected: Cause code for software interrupt is 3, so address = base + (3 * 4).
    expected_cause = 3
    expected_address = 0x80000000 + (expected_cause * 4)
    expected_address_bin = format(expected_address, '032b')

    # Allow a couple of cycles for the new priority to take effect.
    for _ in range(2):
        await trace.cycle()

    yield trace.check(dut.interrupt_out, "1",
                      "interrupt_out should assert when interrupts are pending")
    yield trace.check(dut.interrupt_address, expected_address_bin,
                      "interrupt_address should reflect the software interrupt as first selection")

    # Acknowledge the software interrupt.
    dut.acknowledge.value = BinaryValue("1")
    await trace.cycle()
    dut.acknowledge.value = BinaryValue("0")
    await trace.cycle()
    await trace.cycle()

    # Now, the timer interrupt should be selected.
    # Expected: Cause code for timer interrupt is 7, so address = base + (7 * 4).
    expected_cause = 7
    expected_address = 0x80000000 + (expected_cause * 4)
    expected_address_bin = format(expected_address, '032b')

    # Allow a couple of cycles for the new priority to take effect.
    for _ in range(2):
        await trace.cycle()

    yield trace.check(dut.interrupt_out, "1",
                      "interrupt_out should remain asserted for the pending timer interrupt")
    yield trace.check(dut.interrupt_address, expected_address_bin,
                      "interrupt_address should now reflect the timer interrupt after msip is acknowledged")

    # Acknowledge the timer interrupt.
    dut.acknowledge.value = BinaryValue("1")
    await trace.cycle()
    dut.acknowledge.value = BinaryValue("0")
    await trace.cycle()
    await trace.cycle()
    await trace.cycle()

    # Finally, no interrupts should be pending.
    yield trace.check(dut.interrupt_out, "0",
                      "interrupt_out should deassert after both interrupts are acknowledged")
    
@INTERRUPT_UNIT.testcase
async def tb_INTERRUPT_UNIT_no_starvation(dut: INTERRUPT_UNIT, trace: lib.Waveform):
    """
    Updated No Starvation Test:
      - Over 40 iterations, generate interrupts using the following pattern:
          * For iterations where (i % 3 == 0), trigger a software interrupt (msip) for two cycles.
          * For iterations where (i % 3 == 1), trigger a timer interrupt (mtip) for one cycle.
          * For iterations where (i % 3 == 2), trigger both msip and mtip simultaneously.
      - Each time an interrupt is asserted, capture its cause code (derived from the interrupt_address).
      - At the end, verify that both cause code 3 (software) and cause code 7 (timer) appear in the recorded results.
      This demonstrates that neither interrupt is starved.
    """
    # Reset DUT
    dut.reset_n.value = BinaryValue("0")
    for _ in range(3):
         await trace.cycle()
    dut.reset_n.value = BinaryValue("1")
    await trace.cycle()

    # Setup base address and enable vectored mode.
    dut.mtvec_base.value = BinaryValue(format(0x80000000, '032b'))
    dut.vectored_mode.value = BinaryValue("1")

    # Enable global interrupt and group 0 interrupts.
    dut.mie.value = BinaryValue("1")
    dut.msie.value = BinaryValue("1")
    dut.mtie.value = BinaryValue("1")
    # Disable external interrupt for this test.
    dut.meie.value = BinaryValue("0")

    # Ensure no interrupts are masked.
    dut.mask_write_enable.value = BinaryValue("1")
    dut.mask_write_data.value = BinaryValue("000")
    await trace.cycle()

    # List to record serviced interrupt cause codes.
    cause_codes = []

    # Run for 40 iterations with a varied pattern.
    for i in range(40):
         if i % 3 == 0:
             # Trigger a software interrupt for two cycles.
             dut.msip.value = BinaryValue("1")
             dut.mtip.value = BinaryValue("0")
             await trace.cycle()
             dut.msip.value = BinaryValue("1")
             await trace.cycle()
         elif i % 3 == 1:
             # Trigger a timer interrupt for one cycle.
             dut.msip.value = BinaryValue("0")
             dut.mtip.value = BinaryValue("1")
             await trace.cycle()
         else:  # i % 3 == 2
             # Trigger both interrupts simultaneously.
             dut.msip.value = BinaryValue("1")
             dut.mtip.value = BinaryValue("1")
             await trace.cycle()
         
         # Deassert interrupts to simulate edge-trigger.
         dut.msip.value = BinaryValue("0")
         dut.mtip.value = BinaryValue("0")
         await trace.cycle()

         # If an interrupt is asserted, record its cause code.
         if dut.interrupt_out.value.integer == 1:
             base = 0x80000000
             addr_int = dut.interrupt_address.value.integer
             cause = (addr_int - base) // 4
             cause_codes.append(cause)

             # Acknowledge the interrupt.
             dut.acknowledge.value = BinaryValue("1")
             await trace.cycle()
             dut.acknowledge.value = BinaryValue("0")
             await trace.cycle()
         else:
             # No interrupt asserted; wait one cycle.
             await trace.cycle()

    # Check that both software (cause code 3) and timer (cause code 7) interrupts were serviced.
    if 3 not in cause_codes:
         raise Exception("No Starvation Test: Software interrupt (cause 3) was never serviced.")
    if 7 not in cause_codes:
         raise Exception("No Starvation Test: Timer interrupt (cause 7) was never serviced.")

    # Yield a final result to complete the async generator.
    yield True

@INTERRUPT_UNIT.testcase
async def tb_INTERRUPT_UNIT_stress_test(dut: INTERRUPT_UNIT, trace: lib.Waveform):
    """Test Case 17: Stress testing (random combination of interrupts)"""
    trace.disable()  # Disable waveform tracing for stress testing

    # Reset pending interrupts
    dut.msip.value = BinaryValue("0")
    dut.mtip.value = BinaryValue("0")
    dut.meip.value = BinaryValue("0")

    # Initialize interrupt enables
    dut.msie.value = BinaryValue("0")
    dut.mtie.value = BinaryValue("0")
    dut.meie.value = BinaryValue("0")
    for _ in range(2):
        await trace.cycle()
    dut.msie.value = BinaryValue("1")
    dut.mtie.value = BinaryValue("1")
    dut.meie.value = BinaryValue("1")

    dut.mie.value = BinaryValue("1")

    dut.acknowledge.value = BinaryValue("0")
    dut.vectored_mode.value = BinaryValue("1")
    dut.mtvec_base.value = BinaryValue(format(0x80000000, '032b'))

    for i in range(100):  # Test with 100 random combinations
        # Apply reset
        dut.reset_n.value = BinaryValue("0")
        await trace.cycle()
        dut.reset_n.value = BinaryValue("1")
        await trace.cycle()
        
        # Randomly set pending interrupts
        msip = random.getrandbits(1)
        mtip = random.getrandbits(1)
        meip = random.getrandbits(1)

        dut.msip.value = BinaryValue(str(msip))
        dut.mtip.value = BinaryValue(str(mtip))
        dut.meip.value = BinaryValue(str(meip))

        await trace.cycle()

        # Track the value of the pending signals for testing
        expected_interrupt_out = msip or mtip or meip

        # Deassert interrupts (simulate edge-triggered behavior)
        dut.msip.value = BinaryValue("0")
        dut.mtip.value = BinaryValue("0")
        dut.meip.value = BinaryValue("0")

        # Wait for interrupt to be processed
        for _ in range(3):
            await trace.cycle()

        if expected_interrupt_out == 1:
            
            yield trace.check(dut.interrupt_out, "1", "interrupt_out should remain asserted due to pending interrupts")
            
            # Simulate CPU acknowledgment
            dut.acknowledge.value = BinaryValue("1")
            await trace.cycle()
            dut.acknowledge.value = BinaryValue("0")

            # Wait for interrupt unit to clear the interrupt
            for _ in range(2):
                await trace.cycle()

            # After acknowledgment, interrupt_out should be deasserted
            yield trace.check(dut.interrupt_ack, "0", "interrupt_out should deassert after all acknowledgments")

        else:
            # No interrupt asserted
            yield trace.check(dut.interrupt_out, "0", "interrupt_out should not be asserted if there are no pending interrupts")

@pytest.mark.synthesis
def test_INTERRUPT_UNIT_synthesis():
    INTERRUPT_UNIT.build_vhd()
    INTERRUPT_UNIT.build_netlistsvg()

@pytest.mark.testcases
def test_INTERRUPT_UNIT_testcases_1():
    INTERRUPT_UNIT.test_with(tb_INTERRUPT_UNIT_no_interrupts)

@pytest.mark.testcases
def test_INTERRUPT_UNIT_testcases_2():
    INTERRUPT_UNIT.test_with(tb_INTERRUPT_UNIT_sw_interrupt_not_enabled)

@pytest.mark.testcases
def test_INTERRUPT_UNIT_testcases_3():
    INTERRUPT_UNIT.test_with(tb_INTERRUPT_UNIT_sw_interrupt_enabled)

@pytest.mark.testcases
def test_INTERRUPT_UNIT_testcases_4():
    INTERRUPT_UNIT.test_with(tb_INTERRUPT_UNIT_clear_sw_interrupt)

@pytest.mark.testcases
def test_INTERRUPT_UNIT_testcases_5():
    INTERRUPT_UNIT.test_with(tb_INTERRUPT_UNIT_timer_interrupt)

@pytest.mark.testcases
def test_INTERRUPT_UNIT_testcases_6():
    INTERRUPT_UNIT.test_with(tb_INTERRUPT_UNIT_external_interrupt)

@pytest.mark.testcases
def test_INTERRUPT_UNIT_testcases_7():
    INTERRUPT_UNIT.test_with(tb_INTERRUPT_UNIT_multiple_interrupts)

@pytest.mark.testcases
def test_INTERRUPT_UNIT_testcases_8():
    INTERRUPT_UNIT.test_with(tb_INTERRUPT_UNIT_vectored_mode)

@pytest.mark.testcases
def test_INTERRUPT_UNIT_testcases_9():
    INTERRUPT_UNIT.test_with(tb_INTERRUPT_UNIT_global_interrupt_disable_enable)

@pytest.mark.testcases
def test_INTERRUPT_UNIT_testcases_10():
    INTERRUPT_UNIT.test_with(tb_INTERRUPT_UNIT_change_mtvec_base)

@pytest.mark.testcases
def test_INTERRUPT_UNIT_testcases_11():
    INTERRUPT_UNIT.test_with(tb_INTERRUPT_UNIT_reset_unit)

@pytest.mark.testcases
def test_INTERRUPT_UNIT_testcases_12():
    INTERRUPT_UNIT.test_with(tb_INTERRUPT_UNIT_multiple_sw_interrupts)

@pytest.mark.testcases
def test_INTERRUPT_UNIT_testcases_13():
    INTERRUPT_UNIT.test_with(tb_INTERRUPT_UNIT_simultaneous_interrupts)

@pytest.mark.testcases
def test_INTERRUPT_UNIT_testcases_14():
    INTERRUPT_UNIT.test_with(tb_INTERRUPT_UNIT_interrupt_masking)

@pytest.mark.testcases
def test_INTERRUPT_UNIT_testcases_15():
    INTERRUPT_UNIT.test_with(tb_INTERRUPT_UNIT_two_level_priority)

@pytest.mark.testcases
def test_INTERRUPT_UNIT_testcases_16():
    INTERRUPT_UNIT.test_with(tb_INTERRUPT_UNIT_no_starvation)

@pytest.mark.coverage
def test_INTERRUPT_UNIT_stress():
    INTERRUPT_UNIT.test_with(tb_INTERRUPT_UNIT_stress_test)

if __name__ == "__main__":
    lib.run_test(__file__)
