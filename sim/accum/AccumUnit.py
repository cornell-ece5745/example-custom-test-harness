#=========================================================================
# Accumulator Unit
#=========================================================================

from pymtl3 import *
from pymtl3.passes.backends.verilog import *
from pymtl3.stdlib.mem.ifcs  import MemRequesterIfc
from pymtl3.stdlib.mem       import mk_mem_msg

class AccumUnit( VerilogPlaceholder, Component ):

  def construct( s ):

    MemReqMsg,  MemRespMsg  = mk_mem_msg( 8, 32, 32 )

    s.go        = InPort()
    s.base_addr = InPort( Bits32 )
    s.size      = InPort( Bits32 )
    s.done      = OutPort()
    s.result    = OutPort( Bits32 )

    s.mem  = MemRequesterIfc( MemReqMsg, MemRespMsg )

