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

class TOP_LEVEL(lib.Entity):
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


@TOP_LEVEL.testcase
async def tb_TOP_LEVEL_no_interrupts(dut: TOP_LEVEL, trace: lib.Waveform):
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

    # Wait for a few clock cycles
    await trace.cycle()
    await trace.cycle()

    # Check that interrupt_out remains '0'
    yield trace.check(dut.interrupt_out, "0", "interrupt_out should remain deasserted")

@TOP_LEVEL.testcase
async def tb_TOP_LEVEL_sw_interrupt_not_enabled(dut: TOP_LEVEL, trace: lib.Waveform):
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

@TOP_LEVEL.testcase
async def tb_TOP_LEVEL_sw_interrupt_enabled(dut: TOP_LEVEL, trace: lib.Waveform):
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

@TOP_LEVEL.testcase
async def tb_TOP_LEVEL_clear_sw_interrupt(dut: TOP_LEVEL, trace: lib.Waveform):
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


@TOP_LEVEL.testcase
async def tb_TOP_LEVEL_timer_interrupt(dut: TOP_LEVEL, trace: lib.Waveform):
    """Test Case 5: Timer interrupt pending and enabled"""
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
    for _ in range(4):
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

@TOP_LEVEL.testcase
async def tb_TOP_LEVEL_external_interrupt(dut: TOP_LEVEL, trace: lib.Waveform):
    """Test Case 6: External interrupt pending and enabled"""
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
    for _ in range(4):
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

@TOP_LEVEL.testcase
async def tb_TOP_LEVEL_multiple_interrupts(dut: TOP_LEVEL, trace: lib.Waveform):
    """Test Case 7: Multiple interrupts pending (software and timer)"""
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
    for _ in range(4):
        await trace.cycle()

    # Check if interrupt_out is asserted
    yield trace.check(dut.interrupt_out, "1", "interrupt_out should assert for multiple pending interrupts")

@TOP_LEVEL.testcase
async def tb_TOP_LEVEL_vectored_mode(dut: TOP_LEVEL, trace: lib.Waveform):
    """Test Case 8: Vectored mode enabled and software interrupt triggered"""
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

@TOP_LEVEL.testcase
async def tb_TOP_LEVEL_global_interrupt_disable_enable(dut: TOP_LEVEL, trace: lib.Waveform):
    """Test Case 9: Global interrupt disable and enable"""
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

@TOP_LEVEL.testcase
async def tb_TOP_LEVEL_change_mtvec_base(dut: TOP_LEVEL, trace: lib.Waveform):
    """Test Case 10: Change mtvec_base"""
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

@TOP_LEVEL.testcase
async def tb_TOP_LEVEL_reset_unit(dut: TOP_LEVEL, trace: lib.Waveform):
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

@TOP_LEVEL.testcase
async def tb_TOP_LEVEL_multiple_sw_interrupts(dut: TOP_LEVEL, trace: lib.Waveform):
    """Test Case 12: Multiple software interrupts from the same source"""
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

@TOP_LEVEL.testcase
async def tb_TOP_LEVEL_simultaneous_interrupts(dut: TOP_LEVEL, trace: lib.Waveform):
    """Test Case 13: Simultaneous interrupts from different sources"""
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

@TOP_LEVEL.testcase
async def tb_TOP_LEVEL_stress_test(dut: TOP_LEVEL, trace: lib.Waveform):
    """Test Case 14: Stress testing (random combination of interrupts)"""
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
def test_TOP_LEVEL_synthesis():
    TOP_LEVEL.build_vhd()
    TOP_LEVEL.build_netlistsvg()

@pytest.mark.testcases
def test_TOP_LEVEL_testcases_1():
    TOP_LEVEL.test_with(tb_TOP_LEVEL_no_interrupts)

@pytest.mark.testcases
def test_TOP_LEVEL_testcases_2():
    TOP_LEVEL.test_with(tb_TOP_LEVEL_sw_interrupt_not_enabled)

@pytest.mark.testcases
def test_TOP_LEVEL_testcases_3():
    TOP_LEVEL.test_with(tb_TOP_LEVEL_sw_interrupt_enabled)

@pytest.mark.testcases
def test_TOP_LEVEL_testcases_4():
    TOP_LEVEL.test_with(tb_TOP_LEVEL_clear_sw_interrupt)

@pytest.mark.testcases
def test_TOP_LEVEL_testcases_5():
    TOP_LEVEL.test_with(tb_TOP_LEVEL_timer_interrupt)

@pytest.mark.testcases
def test_TOP_LEVEL_testcases_6():
    TOP_LEVEL.test_with(tb_TOP_LEVEL_external_interrupt)

@pytest.mark.testcases
def test_TOP_LEVEL_testcases_7():
    TOP_LEVEL.test_with(tb_TOP_LEVEL_multiple_interrupts)

@pytest.mark.testcases
def test_TOP_LEVEL_testcases_8():
    TOP_LEVEL.test_with(tb_TOP_LEVEL_vectored_mode)

@pytest.mark.testcases
def test_TOP_LEVEL_testcases_9():
    TOP_LEVEL.test_with(tb_TOP_LEVEL_global_interrupt_disable_enable)

@pytest.mark.testcases
def test_TOP_LEVEL_testcases_10():
    TOP_LEVEL.test_with(tb_TOP_LEVEL_change_mtvec_base)

@pytest.mark.testcases
def test_TOP_LEVEL_testcases_11():
    TOP_LEVEL.test_with(tb_TOP_LEVEL_reset_unit)

@pytest.mark.testcases
def test_TOP_LEVEL_testcases_12():
    TOP_LEVEL.test_with(tb_TOP_LEVEL_multiple_sw_interrupts)

@pytest.mark.testcases
def test_TOP_LEVEL_testcases_13():
    TOP_LEVEL.test_with(tb_TOP_LEVEL_simultaneous_interrupts)

@pytest.mark.coverage
def test_TOP_LEVEL_stress():
    TOP_LEVEL.test_with(tb_TOP_LEVEL_stress_test)

if __name__ == "__main__":
    lib.run_test(__file__)
