#=========================================================================
# AccumUnit_test
#=========================================================================

import pytest
import random
import struct

from pymtl3 import *
from pymtl3.stdlib.test_utils import mk_test_case_table
from pymtl3.stdlib.test_utils import config_model_with_cmdline_opts
from pymtl3.stdlib.mem        import MemoryFL, mk_mem_msg

from accum.AccumUnit import AccumUnit

#-------------------------------------------------------------------------
# TestHarness
#-------------------------------------------------------------------------

class TestHarness( Component ):

  def construct( s, mem_stall_prob=0, mem_latency=0 ):

    s.accum = AccumUnit()
    s.mem   = MemoryFL( 1, mem_ifc_dtypes=[mk_mem_msg(8,32,32)],
                        stall_prob=mem_stall_prob,
                        extra_latency=mem_latency )

    s.mem.ifc[0] //= s.accum.mem

  def line_trace( s ):
    return s.accum.line_trace() + " | " + \
           s.mem.line_trace()

#-------------------------------------------------------------------------
# test_basic
#-------------------------------------------------------------------------

def test_basic( cmdline_opts ):

  # Create the test harness

  th = TestHarness()

  # Configure the test harness

  th = config_model_with_cmdline_opts( th, cmdline_opts, duts=['accum'] )

  # Elaborate the test harness

  th.elaborate()

  # Write values into the magic memory

  data = [ 1, 2, 3, 4 ]
  data_bytes = struct.pack("<4I",*data)
  th.mem.write_mem( 0x1000, data_bytes )

  # Create and reset simulator

  th.apply( DefaultPassGroup(linetrace=True) )
  th.sim_reset()

  # Set the go, base address, and size input ports

  th.accum.go        @= 1
  th.accum.base_addr @= 0x1000
  th.accum.size      @= 4

  # Tick the simulation

  th.sim_tick()

  # Clear the go bit and run the simulation until the done bit is high

  th.accum.go @= 0
  while not th.accum.done and th.sim_cycle_count() < 1000:
    th.sim_tick()

  # Check result

  assert th.accum.done
  assert th.accum.result == 10

  # Extra ticks

  th.sim_tick()
  assert not th.accum.done

  th.sim_tick()
  assert not th.accum.done

  th.sim_tick()
  assert not th.accum.done

#-------------------------------------------------------------------------
# run_test
#-------------------------------------------------------------------------

def run_test( cmdline_opts, data, base_addr, mem_stall_prob, mem_latency ):

  # Create the test harness

  th = TestHarness( mem_stall_prob, mem_latency )

  # Configure the test harness

  th = config_model_with_cmdline_opts( th, cmdline_opts, duts=['accum'] )

  # Elaborate the test harness

  th.elaborate()

  # Write values into the magic memory

  data_bytes = struct.pack(f"<{len(data)}I",*data)
  th.mem.write_mem( base_addr, data_bytes )

  # Create and reset simulator

  th.apply( DefaultPassGroup(linetrace=True) )
  th.sim_reset()

  # Set the go, base address, and size input ports

  th.accum.go        @= 1
  th.accum.base_addr @= base_addr
  th.accum.size      @= len(data)

  # Tick the simulation

  th.sim_tick()

  # Clear the go bit and run the simulation until the done bit is high

  th.accum.go @= 0
  while not th.accum.done and th.sim_cycle_count() < 1000:
    th.sim_tick()

  # Check result

  assert th.accum.done
  assert th.accum.result == sum(data)

  # Extra ticks

  th.sim_tick()
  assert not th.accum.done

  th.sim_tick()
  assert not th.accum.done

  th.sim_tick()
  assert not th.accum.done

#-------------------------------------------------------------------------
# more tests
#-------------------------------------------------------------------------

def test_size4_addr1000_stall0_latency0( cmdline_opts ):
  run_test( cmdline_opts, [ 1, 2, 3, 4 ], 0x1000, 0, 0 )

def test_size4_addr2000_stall0_latency0( cmdline_opts ):
  run_test( cmdline_opts, [ 1, 2, 3, 4 ], 0x2000, 0, 0 )

def test_size8_addr1000_stall0_latency0( cmdline_opts ):
  run_test( cmdline_opts, [ 1, 2, 3, 4, 5, 6, 7, 8 ], 0x1000, 0, 0 )

def test_size8_addr1000_stall0p5_latency4( cmdline_opts ):
  run_test( cmdline_opts, [ 1, 2, 3, 4, 5, 6, 7, 8 ], 0x1000, 0.5, 4 )

#-------------------------------------------------------------------------
# with test case table
#-------------------------------------------------------------------------

mini4  = [ 1, 2, 3, 4 ]
mini8  = [ 1, 2, 3, 4, 5, 6, 7, 8 ]
random = [ random.randint(0,1000) for i in range(32) ]

test_case_table = mk_test_case_table([
  (                      "data            stall lat"),
  [ "mini4",              mini4,          0,    0   ],
  [ "mini8",              mini8,          0,    0   ],
  [ "random",             random,         0,    0   ],
  [ "random_stall0p5",    random,         0.5,  4   ],
  [ "random_stall0p9",    random,         0.9,  4   ],
])

@pytest.mark.parametrize( **test_case_table )
def test( cmdline_opts, test_params ):
  run_test( cmdline_opts, test_params.data,
            0x1000, test_params.stall, test_params.lat  )

