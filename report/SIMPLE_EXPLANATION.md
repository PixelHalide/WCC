# FHSS Project - Simple Explanation

## What this project does

This project simulates two wireless radios communicating while a jammer interferes with part of the available frequency band.

A normal fixed-frequency radio stays on one channel. If that channel is jammed, most or all of the message can be lost. In frequency-hopping spread spectrum (FHSS), the transmitter keeps changing channel according to a shared pseudo-random sequence. The receiver knows the same sequence, follows the transmitter, and recovers the message.

## FHSS is not FSK

In FSK, frequency represents the data:

```text
Bit 0 -> frequency f1
Bit 1 -> frequency f2
```

In this project, BPSK represents the data:

```text
Bit 0 -> +1, or 0-degree phase
Bit 1 -> -1, or 180-degree phase
```

FHSS only decides which carrier frequency carries those BPSK symbols. In short:

> BPSK decides what data is sent. FHSS decides where in the band it is sent.

## Transmitted frame

Each packet contains 320 bits:

| Part | Length | Purpose |
|---|---:|---|
| Preamble | 32 bits | Helps the receiver find and synchronize with the packet |
| Frame counter | 16 bits | Identifies the packet |
| Payload | 256 bits | The actual message data |
| CRC | 16 bits | Detects whether the packet was corrupted |

The CRC detects errors but does not correct them. A packet with a wrong CRC is rejected.

## Hopping system

The system uses eight carrier offsets from -87.5 kHz to +87.5 kHz. Adjacent channels are 25 kHz apart. The BPSK signal occupies approximately 20 kHz, so the total hopping bandwidth is:

```text
(8 - 1) x 25 kHz + 20 kHz = 195 kHz
```

The transmitter and receiver use the same random seed. This lets them independently generate the same repeatable hopping sequence. Every block of eight hops visits all eight channels once.

Three hopping speeds are tested:

| Symbols per hop | Time on one channel | Hop rate |
|---:|---:|---:|
| 16 | 1.6 ms | 625 hops/s |
| 8 | 0.8 ms | 1,250 hops/s |
| 4 | 0.4 ms | 2,500 hops/s |

## Transmitter operation

The transmitter performs the following steps:

```text
Generate payload
    -> add frame counter and CRC
    -> add the known preamble
    -> convert bits to BPSK symbols
    -> generate the hopping sequence
    -> transmit each group of symbols on its assigned frequency
```

The sample rate is 500,000 samples/s and the symbol rate is 10,000 symbols/s. Therefore, MATLAB represents each BPSK symbol using 50 samples.

The simulation uses frequency offsets around a nominal 2.4 GHz carrier instead of directly sampling a 2.4 GHz waveform. This low-IF representation produces the same hopping and interference behaviour with a practical sample rate.

## Channel and jammer

The channel adds two impairments:

1. AWGN, which represents ordinary random noise.
2. A partial-band jammer, which occupies only some hopping channels.

The experiments test jammer occupancies of 12.5%, 25%, and 50%, meaning that 1, 2, or 4 of the 8 channels are jammed. The total jammer power is kept fixed at a jammer-to-signal ratio of 10 dB.

A narrow jammer is stronger on each occupied channel but causes fewer collisions. A wider jammer is weaker on each channel but collides with more hops.

## Receiver operation

The receiver initially does not know the exact packet start time or the transmitter's current position in the hopping sequence.

It tests possible timing positions and hopping-code offsets. For every candidate, it dehops the signal and compares the first 32 detected bits with the known preamble. A candidate is accepted when its correlation is high enough and at least 28 of the 32 preamble bits agree.

After synchronization, the receiver:

```text
recreates the winning hopping sequence
    -> removes the hopping carrier (dehopping)
    -> adds the 50 samples belonging to each symbol
    -> decides whether each BPSK symbol is bit 0 or bit 1
    -> finds and extracts the frame
    -> checks the CRC
```

If the receiver follows the wrong hopping position, it listens on the wrong frequencies. Its bit decisions then become almost random.

## Measurements

Bit error rate (BER) is the fraction of payload bits recovered incorrectly:

```text
BER = incorrect payload bits / total payload bits
```

Packet error rate (PER) is the fraction of complete packets that fail synchronization or CRC:

```text
PER = failed packets / transmitted packets
```

PER can be high even when BER is moderate because one incorrect bit can make the CRC reject a complete packet.

The project varies noise level, jammer occupancy, hop rate, hopping-code alignment, and receiver hop-rate error. It also compares FHSS with fixed-frequency BPSK at the same average power.

## Main findings

- Without the jammer, the simulated BPSK error rate agrees with theoretical BPSK.
- Increasing Eb/N0 reduces errors caused by AWGN.
- Strong partial-band interference creates an error floor that extra signal-to-noise ratio cannot completely remove.
- A forced one-hop sequence offset gives a BER near 0.5, showing that hop synchronization is essential.
- A small receiver hop-rate error accumulates across the packet and eventually misaligns the receiver.
- FHSS performs much better than a fixed link stuck inside the jammed band.
- A guaranteed clean fixed channel performs best, but that assumes the clean channel is already known and remains clean.

## Recommendation

The measured results recommend:

```text
Hop-set size: 8 channels
Hop rate:     1,250 hops/s
Symbols/hop:  8
Dwell time:   0.8 ms
```

This is a useful middle ground: it leaves a jammed channel faster than the 625 hops/s option while being less demanding to synchronize than 2,500 hops/s.

## One-paragraph presentation summary

This project implements a framed BPSK frequency-hopping link in MATLAB. The transmitter and receiver share a seeded pseudo-random sequence that moves the signal among eight channels. A known preamble lets the receiver determine packet timing and hopping-code position before it dehops and demodulates the signal. CRC-16 detects corrupted frames. AWGN and a partial-band jammer are added to study BER, PER, synchronization, hopping-rate mismatch, and the difference between FHSS and fixed-frequency transmission. The results show that FHSS is more reliable than remaining on a jammed fixed channel, but accurate synchronization is essential. Eight channels at 1,250 hops/s are recommended for the simulated 195 kHz band.
