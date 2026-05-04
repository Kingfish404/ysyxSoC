package ysyx

import chisel3._
import chisel3.util._

import org.chipsalliance.cde.config.Parameters
import freechips.rocketchip.subsystem._
import freechips.rocketchip.amba.axi4._
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.util._

object CPUAXI4BundleParameters {
  def apply() = AXI4BundleParameters(addrBits = 32, dataBits = 32, idBits = ChipLinkParam.idBits)
}

class rapt extends BlackBox {
  val io = IO(new Bundle {
    val clock = Input(Clock())
    val reset = Input(Reset())
    val io_interrupt = Input(Bool())
    val io_master = AXI4Bundle(CPUAXI4BundleParameters())
    val io_slave = Flipped(AXI4Bundle(CPUAXI4BundleParameters()))
    // External IRQ vector into the cluster PLIC (sources 1..31). Tied off in
    // Impl below; ysyxSoC has no PLIC source aggregator.
    val ext_irq_i = Input(UInt(31.W))
    // JTAG / RISC-V Debug ports. Always present on rapt; tied to TLR-park
    // here so the DTM stays parked (no JTAG header on ysyxSoC).
    val jtag_trst_n = Input(Bool())
    val jtag_tms   = Input(Bool())
    val jtag_tdi   = Input(Bool())
    val jtag_tdo   = Output(Bool())
  })
}

class CPU(idBits: Int)(implicit p: Parameters) extends LazyModule {
  val masterNode = AXI4MasterNode(p(ExtIn).map(params =>
    AXI4MasterPortParameters(
      masters = Seq(AXI4MasterParameters(
        name = "cpu",
        id   = IdRange(0, 1 << idBits))))).toSeq)
  lazy val module = new Impl
  class Impl extends LazyModuleImp(this) {
    val (master, _) = masterNode.out(0)
    val interrupt = IO(Input(Bool()))
    val slave = IO(Flipped(AXI4Bundle(CPUAXI4BundleParameters())))

    val cpu = Module(new rapt)
    cpu.io.clock := clock
    cpu.io.reset := reset
    cpu.io.io_interrupt := interrupt
    cpu.io.io_slave <> slave
    master <> cpu.io.io_master
    // External IRQ aggregator not present in ysyxSoC; tie off.
    cpu.io.ext_irq_i := 0.U
    // JTAG: park DTM in TLR via trst_n=0, tms=1, tdi=0; tdo is unused.
    cpu.io.jtag_trst_n := false.B
    cpu.io.jtag_tms    := true.B
    cpu.io.jtag_tdi    := false.B
  }
}
