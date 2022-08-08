# Round Robin Arbiter component

## Component description

The commponent implements arbitration between the PORTS_QTY different AXIS streams. The component implements fair arbitration between streams based on the _tlast signal, that it, when the _tvalid, _tready, _tlast signals are received, the component switches among streams and updates its internal state to provide fair arbitration.

## Interface

Parameters:

* PORTS_QTY - number of ports to be served. In current implementation should be a power of 2.
* TDATA_WIDTH - the width of the _tdata buses.
* TDATA_WIDTH - the width of the _tuser buses.

Ports:

* s_axis_data_tvalid - PORTS_QTY-bit bus. Each bit represents the _tvalid signal of a partucalar stream. It indicates an incoming request to be served.
* s_axis_data_tready - PORTS_QTY-bit bus. Each bit represents the _tready signal of a particular stream. It indicates that the master can advance datata stream.
* s_axis_data_tlast - PORTS_QTY-bit bus. Each bit represents the _tlast signal of a particular stream. It indicates that the current item of the stream is the last one in the frame.
* s_axis_data_tdata - PORTS_QTY*TDATA_WIDTH-bit bus. The bus has PORTS_QTY parts. Each part has TDATA_WIDTH bits. Each part represents the _tdata signal of a particular stream.
* s_axis_data_tuser - PORTS_QTY*TUSER_WIDTH-bit bus. The bus has PORTS_QTY parts. Each part has TUSER_WIDTH bits. Each part represents the _tdata signal of a particular stream.
* m_axis_data_tvalid - one-bit signal. Represents the _tvalid signal of a chosen stream.
* m_axis_data_tread - one-bit signal. Represents the _tready signal of a chosen stream.
* m_axis_data_tlast - one-bit signal. Represents the _tlast signal of a chosen stream.
* m_axis_data_tdata - TDATA_WIDTH-bit bus. Represents the _tdata signal of a chosen stream.
* m_axis_data_tuser - TUSER_WIDTH-bit bus. Represents the _tuser signal of a chosen stream.

## Implementation description

The Round Robin arbitration algorithm based on the Matt Weber's "Arbiters: Design Ideas and Coding Styles" article that could be found in Internet.

Arbitration between streams requires one cycle.
