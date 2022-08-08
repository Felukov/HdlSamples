# Crossbar component

## Component description

The Crossbar component allows to interconnect up to 4x4 master-slave devices. The implementation based on the requirements from https://syntacore.com/media/files/trial_task_rtl.pdf.

## Interface

Ports:

* {master|slave}_{N}_req - one-bit signal. A request to execute a master-to-slave transaction
* {master|slave}_{N}_req - 32-bit bus. The bus contains the request address
* {master|slave}_{N}_req - one-bit signal. It contains the operation type. 0 is a read operation, 1 is a write operation
* {master|slave}_{Nt}_wdata - 32-bit bus. Data to be written. The data is valid on the same cycle as the address.
* {master|slave}_{N}_ack - one-bit signal that acknowledges that a slave has taken the request. The slave should latch the _addr, _cmd, and _wdata signals on the same cycle. Asserting the _ack signal in an active state allows the master device drop a request on the next cycle.
* {master|slave}_{N}_resp - one-bit signal indicating that there is a respone from the slave
* {master|slave}_{N}_rdata - 32-bit bus. The response from the slave.

### Functional requirements

The high bits of the address determine selection of a slave. The amount of used bits is calcuated as the power of 2 that is sufficient to represent all slave devices.

The arbitration between the several master requests to a single slave device should be done via a round-robin algorithm.

The slave device can take up to 4 read requests before it will generate output results.

## Implementation description

The component represents by itself a pipeline with the following stages:

* mapping requests for each slave. At that stage all incoming requests mapped to slaves according to the hi bits of the address in the request. If there is a match then the signal m2s_req[N] is set to one, otherwise the signal is masked. At the same cycle m2s_tag[N] signal is latched for read requests in order to provide information for the reorder buffer on the following stages.
* for each slave there is a round-robin arbitration logic that allows to implement a fair selection of a master request to be served. The selected request for a particular master is forwarded to the slave bus. The index of the served master and the tag acquired at the first stage are stored in the FIFO queue for read requests.
* when the slave sets the _resp signal, the component combines the data from the FIFO queue with the data from the slave bus and forward the combined data into reorder buffer for a specific master.
* the reorder buffer updates its internal storage with provided data and if the received response is the first one that should to be forwarded to the master the reorder buffer forwards the response to master's bus.
