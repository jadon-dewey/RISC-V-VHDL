from sre_constants import IN
import pytest
from cocotb.binary import BinaryValue
import lib

class TOP_LEVEL(lib.Entity):
    clock = lib.Entity.Input_pin
    en = lib.Entity.Input_pin
    input_A = lib.Entity.Input_pin
    input_B = lib.Entity.Input_pin
    final_result = lib.Entity.Output_pin

@TOP_LEVEL.testcase
async def tb_TOP_LEVEL_case_1(dut: TOP_LEVEL, trace: lib.Waveform):
    dut.en.value = BinaryValue("1")

    #Basic zero multiplicatiion
    dut.input_A.value = BinaryValue("1000000000000000")
    dut.input_B.value = BinaryValue("0000000000000000")

    await trace.cycle(5)
    yield trace.check(dut.final_result, "00000000000000000000000000000000" , "At clock 0.")

    #Simple Positive Multiplication
    dut.input_A.value = BinaryValue("0000000000000011")
    dut.input_B.value = BinaryValue("0000000000000101")

    await trace.cycle(5)
    yield trace.check(dut.final_result, "00000000000000000000000000001111", "At clock 1.")

    #Simple positive Multiplciation
    dut.input_A.value = BinaryValue("0000000000000111")
    dut.input_B.value = BinaryValue("0000000000000101")

    await trace.cycle(5)
    yield trace.check(dut.final_result, "00000000000000000000000000100011", "At clock 2.")

    #Larger Positive Multiplication
    dut.input_A.value = BinaryValue("0000001110000111")
    dut.input_B.value = BinaryValue("0011111000011110")

    await trace.cycle(5)
    yield trace.check(dut.final_result, "00000000110110110001101111010010", "At clock 3.")


    dut.input_A.value = BinaryValue("1000000000000000")
    dut.input_B.value = BinaryValue("1000000000000000")

    await trace.cycle(5)
    yield trace.check(dut.final_result, "01000000000000000000000000000000", "At clock 4.")

    # Negative Alternating test (2*-4 = -8)
    dut.input_A.value = BinaryValue("0000000000000010")
    dut.input_B.value = BinaryValue("1111111111111100")

    await trace.cycle(5)
    yield trace.check(dut.final_result, "11111111111111111111111111111000", "At clock 5.")

    # Negative Alternating test (7*-32768 = -229376)
    dut.input_A.value = BinaryValue("0000000000000111")
    dut.input_B.value = BinaryValue("1000000000000000")

    await trace.cycle(5)
    yield trace.check(dut.final_result, "11111111111111001000000000000000", "At clock 6.")

    # Small double negative operand test (-5*-7 = 35)
    dut.input_A.value = BinaryValue("1111111111111011")
    dut.input_B.value = BinaryValue("1111111111111001")

    await trace.cycle(5)
    yield trace.check(dut.final_result, "00000000000000000000000000100011", "At clock 7.")

    #Max value edge case 32767 *32767 = 1073676289
    #Maximum positive value 2^15-1 = 32767^2

    dut.input_A.value = BinaryValue("0111111111111111")  # +32,767
    dut.input_B.value = BinaryValue("0111111111111111")  # +32,767

    await trace.cycle(5)
    yield trace.check(dut.final_result, "00111111111111110000000000000001", "At clock 8.")

    dut.input_A.value = BinaryValue("0111111111111111")  # +32,767
    dut.input_B.value = BinaryValue("0111111111111111")  # +32,767

    await trace.cycle(5)
    yield trace.check(dut.final_result, "00111111111111110000000000000001", "At clock 9.")

    



@pytest.mark.synthesis
def test_TOP_LEVEL_synthesis():
    TOP_LEVEL.build_vhd()
    TOP_LEVEL.build_netlistsvg()

@pytest.mark.testcases
def test_MODULE_REGISTER_FILE_testcases():
    TOP_LEVEL.test_with(tb_TOP_LEVEL_case_1)

if __name__ == "__main__":
    lib.run_test(__file__)

