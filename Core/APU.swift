//
//  APU.swift (NONFUNCTIONAL ATM)
//  IgnacioNES
//
//  Adapted from OpenSource and Edited by Ignacio Estrada on 11/25/24.
//

import Foundation

import Foundation
import AudioToolbox

final class APUBuffer {
    var apu: APU?
    
    private let BUFFERSIZE = 44100
    // 8820
    private let IDEALCAPACITY = 44100 * 0.2
    private let CPUFREQENCY = 1789773.0
    private let SAMPLERATE = 44100.0
    private let SAMPLERATEDIVISOR = 1789773.0 / 44100.0
    private let ALPHA = 0.00005
    
    private var buffer: [Int16]
    private var startIndex: Int
    private var endIndex: Int
    
    private var rollingSamplesToGet: Double
    
    init() {
        apu = nil
        
        buffer = [Int16](repeating: 0, count: BUFFERSIZE)
        
        startIndex = 0
        endIndex = Int(IDEALCAPACITY)
        
        rollingSamplesToGet = SAMPLERATEDIVISOR
    }
    
    func availableSampleCount() -> Int {
        if endIndex < startIndex {
            return BUFFERSIZE - startIndex + endIndex
        }
        
        return endIndex - startIndex
    }
    
    func saveSample(_ sampleData: Int16) {
        buffer[endIndex] = sampleData
        
        endIndex += 1
        
        if endIndex >= BUFFERSIZE {
            endIndex = 0
        }
        
        if startIndex == endIndex {
            print("Buffer overflow")
        }
    }
    
    func loadBuffer(_ audioBuffer: AudioQueueBufferRef) {
//        let array = UnsafeMutablePointer<Int16>(audioBuffer.pointee.mAudioData)
        
        let size = Int(audioBuffer.pointee.mAudioDataBytesCapacity / 2)
        
        let array = UnsafeMutableBufferPointer(start: audioBuffer.pointee.mAudioData.assumingMemoryBound(to: Int16.self), count: size)
        
        let sampleCount = Double(availableSampleCount())
        
        let capacityModifier = sampleCount / IDEALCAPACITY
        
        rollingSamplesToGet = ALPHA * SAMPLERATEDIVISOR * capacityModifier + (1 - ALPHA) * rollingSamplesToGet
        
        apu?.sampleRateDivisor = rollingSamplesToGet
        
        for i in 0 ..< size {
            array[i] = buffer[startIndex]
            
            startIndex += 1

            if startIndex >= BUFFERSIZE {
                startIndex = 0
            }

            if startIndex == endIndex {
                print("Buffer underflow")
            }
        }
        
        audioBuffer.pointee.mAudioDataByteSize = UInt32(size * 2)
    }
}

class APURegister {
    
    let lengthTable: [UInt8] = [0x0A, 0xFE, 0x14, 0x02, 0x28, 0x04, 0x50, 0x06, 0xA0, 0x08, 0x3C,
                                0x0A, 0x0E, 0x0C, 0x1A, 0x0E, 0x0C, 0x10, 0x18, 0x12, 0x30, 0x14,
                                0x60, 0x16, 0xC0, 0x18, 0x48, 0x1A, 0x10, 0x1C, 0x20, 0x1E]
    
    let dutyTable: [[UInt8]] = [[0, 1, 0, 0, 0, 0, 0, 0], [0, 1, 1, 0, 0, 0, 0, 0], [0, 1, 1, 1, 1, 0, 0, 0], [1, 0, 0, 1, 1, 1, 1, 1]]
    
    let noiseTable: [UInt16] = [4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068]
    
    // Register 4
    var lengthCounter: UInt8 {
        didSet {
            wavelength = (wavelength & 0xFF) | (UInt16(lengthCounter & 0x7) << 8)
            lengthCounterLoad = lengthTable[Int((lengthCounter >> 3) & 0x1F)]
        }
    }
    // 3 bits
    var wavelength: UInt16
    // 5 bits
    var lengthCounterLoad: UInt8
    
    var lengthCounterDisable: Bool
    
    var timer: UInt16
    
    init() {
        lengthCounter = 0
        wavelength = 0
        lengthCounterLoad = 0
        
        timer = 0
        
        lengthCounterDisable = true
    }
    
    func stepLength() {
        if !lengthCounterDisable && lengthCounterLoad > 0 {
            lengthCounterLoad -= 1
        }
    }
}

final class Square: APURegister {
    
    // Register 1
    var control: UInt8 {
        didSet {
            envelopeDisable = control & 0x10 == 0x10
            lengthCounterDisable = control & 0x20 == 0x20
            dutyCycleType = (control >> 6) & 0x3
            
            envelopePeriod = control & 0xF
            constantVolume = envelopePeriod
            
            envelopeShouldUpdate = true
        }
    }
    // 4 bits
    var volume: UInt8
    var envelopeDisable: Bool
    // 2 bits
    var dutyCycleType: UInt8
    
    // Register 2
    var sweep: UInt8 {
        didSet {
            sweepShift = sweep & 0x7
            decreaseWavelength = sweep & 0x8 == 0x8
            sweepUpdateRate = (sweep >> 4) & 0x7
            sweepEnable = sweep & 0x80 == 0x80
            
            sweepShouldUpdate = true
        }
    }
    // 3 bits
    var sweepShift: UInt8
    var decreaseWavelength: Bool
    // 3 bits
    var sweepUpdateRate: UInt8
    var sweepEnable: Bool
    
    // Register 3
    var wavelengthLow: UInt8 {
        didSet {
            wavelength = (wavelength & 0xFF00) | UInt16(wavelengthLow)
        }
    }
    
    // Register 4
    override var lengthCounter: UInt8 {
        didSet {
            wavelength = (wavelength & 0xFF) | (UInt16(lengthCounter & 0x7) << 8)
            lengthCounterLoad = lengthTable[Int((lengthCounter >> 3) & 0x1F)]
            dutyIndex = 0
            envelopeShouldUpdate = true
        }
    }
    
    private var channel2: Bool
    
    var sweepShouldUpdate: Bool
    var sweepValue: UInt8
    var targetWavelength: UInt16
    
    var dutyIndex: Int
    
    var envelopeShouldUpdate: Bool
    var envelopePeriod: UInt8
    var envelopeVolume: UInt8
    var constantVolume: UInt8
    var envelopeValue: UInt8
    
    override convenience init() {
        self.init(isChannel2: false)
    }
    
    init(isChannel2: Bool) {
        control = 0
        volume = 0
        envelopeDisable = false
        dutyCycleType = 0
        
        sweep = 0
        sweepShift = 0
        decreaseWavelength = false
        sweepUpdateRate = 0
        sweepEnable = false
        
        wavelengthLow = 0
        
        channel2 = isChannel2
        
        sweepShouldUpdate = false
        sweepValue = 0
        targetWavelength = 0
        
        dutyIndex = 0
        
        envelopeShouldUpdate = false
        envelopePeriod = 0
        envelopeVolume = 0
        constantVolume = 0
        envelopeValue = 0
        
        super.init()
    }
    
    func stepSweep() {
        if sweepShouldUpdate {
            if sweepEnable && sweepValue == 0 {
                sweepUpdate()
            }
            
            sweepValue = sweepUpdateRate
            sweepShouldUpdate = false
        } else if sweepValue > 0 {
            sweepValue -= 1
        } else {
            if sweepEnable {
                sweepUpdate()
            }
            
            sweepValue = sweepUpdateRate
        }
    }
    
    private func sweepUpdate() {
        let delta = wavelength >> UInt16(sweepShift)
        
        if decreaseWavelength {
            targetWavelength = wavelength - delta
            
            if !channel2 {
                targetWavelength += 1
            }
        } else {
            targetWavelength = wavelength + delta
        }
        
        if sweepEnable && sweepShift != 0 && wavelength > 7 && targetWavelength < 0x800 {
            wavelength = targetWavelength
        }
    }
    
    func stepTimer() {
        if timer == 0 {
            timer = wavelength
            dutyIndex = (dutyIndex + 1) % 8
        } else {
            timer -= 1
        }
    }
    
    func stepEnvelope() {
        if envelopeShouldUpdate {
            envelopeVolume = 0xF
            envelopeValue = envelopePeriod
            envelopeShouldUpdate = false
        } else if envelopeValue > 0 {
            envelopeValue -= 1
        } else {
            if envelopeVolume > 0 {
                envelopeVolume -= 1
            } else if lengthCounterDisable {
                envelopeVolume = 0xF
            }
            
            envelopeValue = envelopePeriod
        }
    }
    
    func output() -> UInt8 {
        if lengthCounterLoad == 0 || dutyTable[Int(dutyCycleType)][dutyIndex] == 0 || wavelength < 8 || targetWavelength > 0x7FF {
            return 0
        }
        
        if(!envelopeDisable) {
            return envelopeVolume
        }
        
        return constantVolume
    }
}

final class Triangle: APURegister {
    
    // Register 1
    var control: UInt8 {
        didSet {
            linearCounterLoad = control & 0x7F
            lengthCounterDisable = control & 0x80 == 0x80
        }
    }
    // 7 bits
    var linearCounterLoad: UInt8
    
    // Register 2 not used
    
    // Register 3
    var wavelengthLow: UInt8 {
        didSet {
            wavelength = (wavelength & 0xFF00) | UInt16(wavelengthLow)
        }
    }
    
    override var lengthCounter: UInt8 {
        didSet {
            wavelength = (wavelength & 0xFF) | (UInt16(lengthCounter & 0x7) << 8)
            lengthCounterLoad = lengthTable[Int((lengthCounter >> 3) & 0x1F)]
            timer = wavelength
            linearReload = true
        }
    }
    
    var linearCounter: UInt8
    var linearReload: Bool
    
    var triangleGenerator: UInt8
    var triangleIncreasing: Bool
    
    override init() {
        control = 0
        linearCounterLoad = 0
        
        wavelengthLow = 0
        
        linearCounter = 0
        linearReload = false
        
        triangleGenerator = 0
        triangleIncreasing = true
    }
    
    func stepLinear() {
        if linearReload {
            linearCounter = linearCounterLoad
        } else if linearCounter > 0 {
            linearCounter -= 1
        }
        
        if !lengthCounterDisable {
            linearReload = false
        }
    }
    
    func stepTriangleGenerator() {
        if triangleGenerator == 0 && !triangleIncreasing {
            triangleIncreasing = true
            return
        } else if triangleGenerator == 0xF && triangleIncreasing {
            triangleIncreasing = false
            return
        }
        
        if triangleIncreasing {
            triangleGenerator += 1
        } else {
            triangleGenerator -= 1
        }
    }
    
    func stepTimer() {
        if timer == 0 {
            timer = wavelength
            if lengthCounterLoad > 0 && linearCounter > 0 {
                stepTriangleGenerator()
            }
        } else {
            timer -= 1
        }
    }
    
    func output() -> Double {
        if lengthCounterLoad == 0 || linearCounter == 0 {
            return 0
        }
        
        if wavelength == 0 || wavelength == 1 {
            return 7.5
        }
        
        return Double(triangleGenerator)
    }
}

final class Noise: APURegister {
    
    var control: UInt8 {
        didSet {
            constantVolume = control & 0xF
            envelopePeriod = constantVolume
            
            envelopeDisable = control & 0x10 == 0x10
            lengthCounterDisable = control & 0x20 == 0x20
            dutyCycleType = (control >> 6) & 0x3
        }
    }
    // 4 bits
    var constantVolume: UInt8
    var envelopeDisable: Bool
    var dutyCycleType: UInt8
    
    // Register 2 unused
    
    // Register 3
    var period: UInt8 {
        didSet {
            sampleRate = noiseTable[Int(period & 0xF)]
            randomNumberGeneration = period & 0x80 == 0x80
        }
    }
    // 4 bits
    var sampleRate: UInt16
    // 3 unused bits
    var randomNumberGeneration: Bool
    
    // 3 unused bits in register 4 (msbWavelength)
    override var lengthCounter: UInt8 {
        didSet {
            lengthCounterLoad = lengthTable[Int((lengthCounter >> 3) & 0x1F)]
            envelopeShouldUpdate = true
        }
    }
    
    var shiftRegister: UInt16
    
    var envelopeShouldUpdate: Bool
    var envelopePeriod: UInt8
    var envelopeVolume: UInt8
    var envelopeValue: UInt8
    
    override init() {
        control = 0
        constantVolume = 0
        envelopeDisable = false
        dutyCycleType = 0
        
        period = 0
        sampleRate = 0
        randomNumberGeneration = false
        
        shiftRegister = 1
        
        envelopeShouldUpdate = false
        envelopePeriod = 0
        envelopeVolume = 0
        envelopeValue = 0
    }
    
    func stepTimer() {
        if timer == 0 {
            timer = sampleRate
            
            let shift: UInt16 = randomNumberGeneration ? 6 : 1
            
            let bit0 = shiftRegister & 0x1
            let bit1 = (shiftRegister >> shift) & 0x1
            
            shiftRegister = shiftRegister >> 1
            shiftRegister |= (bit0 ^ bit1) << 14
        } else {
            timer -= 1
        }
    }
    
    func stepEnvelope() {
        if envelopeShouldUpdate {
            envelopeVolume = 0xF
            envelopeValue = envelopePeriod
            envelopeShouldUpdate = false
        } else if envelopeValue > 0 {
            envelopeValue -= 1
        } else {
            if envelopeVolume > 0 {
                envelopeVolume -= 1
            } else if lengthCounterDisable {
                envelopeVolume = 0xF
            }
            
            envelopeValue = envelopePeriod
        }
    }
    
    func output() -> UInt8 {
        if lengthCounterLoad == 0 || shiftRegister & 0x1 == 1 {
            return 0
        }
        
        if !envelopeDisable {
            return envelopeVolume
        }
        
        return constantVolume
    }
}

final class DMC {
    let rateTable: [UInt16] = [428, 380, 340, 320, 286, 254, 226, 214, 190, 160, 142, 128, 106, 84, 72, 54]
    
    var control: UInt8 {
        didSet {
            irqEnabled = control & 0x80 == 0x80
            
            if !irqEnabled {
                dmcIRQ = false
            }
            
            loopEnabled = control & 0x40 == 0x40
            rate = rateTable[Int(control & 0xF)]
            timer = rate
        }
    }
    
    var irqEnabled: Bool
    var loopEnabled: Bool
    var rate: UInt16
    
    var directLoad: UInt8 {
        didSet {
            volume = directLoad & 0x7F
        }
    }
    
    var address: UInt8 {
        didSet {
            currentAddress = 0xC000 | (UInt16(address) << 6)
        }
    }
    
    private var currentAddress: UInt16
    
    var sampleLength: UInt8 {
        didSet {
//            self.sampleLengthRemaining = (UInt16(sampleLength) << 4) | 1
        }
    }
    
    var sampleLengthRemaining: UInt16
    
    private var timer: UInt16
    private var volume: UInt8
    var dmcIRQ: Bool
    
    private var shiftCount: Int
    
    var buffer: UInt8
    
    let memory: Memory
    var cpu: CPU?
    
    init(memory: Memory) {
        self.memory = memory
        cpu = nil
        
        control = 0
        irqEnabled = false
        loopEnabled = false
        rate = 0
        
        directLoad = 0
        
        address = 0
        currentAddress = 0
        
        sampleLength = 0
        sampleLengthRemaining = 0
        
        timer = 0
        volume = 0
        dmcIRQ = false
        shiftCount = 0
        
        buffer = 0
    }
    
    func restart() {
        currentAddress = 0xC000 | (UInt16(address) << 6)
        sampleLengthRemaining = (UInt16(sampleLength) << 4) | 1
    }
    
    func stepTimer() {
        stepReader()
        
        if timer == 0 {
            timer = rate
            stepShifter()
        } else {
            timer -= 1
        }
    }
    
    func stepReader() {
        if sampleLengthRemaining > 0 && shiftCount == 0 {
            // TODO: Delay CPU by 4 cycles (varies, see http://forums.nesdev.com/viewtopic.php?p=62690#p62690)
//            cpu?.startDMCTransfer()
            buffer = memory.readMemory(currentAddress)
            
            shiftCount = 8
            
            currentAddress += 1
            
            if currentAddress > 0xFFFF {
                currentAddress = 0x8000
            }
            
            sampleLengthRemaining -= 1
            
            if sampleLengthRemaining == 0 {
                if loopEnabled {
                    restart()
                } else if irqEnabled {
                    dmcIRQ = true
                }
            }
        }
    }
    
    func stepShifter() {
        if shiftCount == 0 {
            return
        }
        
        if buffer & 0x1 == 0x1 {
            if volume < 126 {
                volume += 2
            }
        } else {
            if volume > 1 {
                volume -= 2
            }
        }
        
        buffer = buffer >> 1
        shiftCount -= 1
    }
    
    func output() -> UInt8 {
        return volume
    }
}

final class APU {
    // MARK: - APU Registers
    
    private var control: UInt8 {
        didSet {
            square1Enable = control & 0x1 == 0x1
            square2Enable = control & 0x2 == 0x2
            triangleEnable = control & 0x4 == 0x4
            noiseEnable = control & 0x8 == 0x8
            dmcEnable = control & 0x10 == 0x10
            
            if !square1Enable {
                square1.lengthCounterLoad = 0
            }
            
            if !square2Enable {
                square2.lengthCounterLoad = 0
            }
            
            if !triangleEnable {
                triangle.lengthCounterLoad = 0
            }
            
            if !noiseEnable {
                noise.lengthCounterLoad = 0
            }
            
            if !dmcEnable {
                dmc.sampleLengthRemaining = 0
            } else if dmc.sampleLengthRemaining == 0 {
                dmc.restart()
            }
            
            dmc.dmcIRQ = false
        }
    }
    
    private var square1Enable: Bool
    private var square2Enable: Bool
    private var triangleEnable: Bool
    private var noiseEnable: Bool
    private var dmcEnable: Bool
    
    private var timerControl: UInt8 {
        didSet {
            disableIRQ = timerControl & 0x40 == 0x40
            
            if disableIRQ {
                frameIRQ = false
            }
            
            framerateSwitch = timerControl & 0x80 == 0x80
            
            if evenCycle {
                cycle = 0
            } else {
                cycle = -1
            }
        }
    }
    
    private var disableIRQ: Bool
    
    /**
        If true, 5 frames occur in each frame counter cycle, otherwise 4
    */
    private var framerateSwitch: Bool
    
    // MARK: - APU Variables
    
    private let square1: Square
    private let square2: Square
    private let triangle: Triangle
    private let noise: Noise
    private let dmc: DMC
    
    private var frameIRQ: Bool
    private var irqDelay: Int
    
    private var cycle: Int
    
    private var sampleBuffer: Double
    private var sampleCount: Double
    private var outputCycle: Int
    var sampleRateDivisor: Double
    private var evenCycle: Bool
    
    var cpu: CPU? {
        didSet {
            dmc.cpu = cpu
        }
    }
    var buffer: APUBuffer
    
    init(memory: Memory) {
        control = 0
        square1Enable = false
        square2Enable = false
        triangleEnable = false
        noiseEnable = false
        dmcEnable = false
        
        timerControl = 0
        disableIRQ = true
        framerateSwitch = false
        
        square1 = Square()
        square2 = Square(isChannel2: true)
        triangle = Triangle()
        noise = Noise()
        dmc = DMC(memory: memory)
        
        frameIRQ = false
        irqDelay = -1
        
        cycle = 0
        
        sampleBuffer = 0
        sampleCount = 0
        outputCycle = 0
        
        sampleRateDivisor = 1789773.0 / 44100.0
        
        evenCycle = true
        
        buffer = APUBuffer()
        
        buffer.apu = self
    }
    
    // MARK: - APU Functions
    
    func step() {
        if evenCycle {
            // Square timers only tick every other cycle
            square1.stepTimer()
            square2.stepTimer()
            noise.stepTimer()
        }
        
        triangle.stepTimer()
        dmc.stepTimer()
        
        stepFrame()
        
        let oldCycle = outputCycle
        outputCycle += 1
        
        if Int(Double(oldCycle) / sampleRateDivisor) != Int(Double(outputCycle) / sampleRateDivisor) {
            sampleBuffer += outputValue()
            sampleCount += 1
            
            buffer.saveSample(Int16(sampleBuffer / sampleCount * 32767))
            
            sampleBuffer = 0
            sampleCount = 0
        } else {
            sampleBuffer += outputValue()
            sampleCount += 1
        }
        
        if irqDelay > -1 {
            irqDelay -= 1
            
            if irqDelay == 0 {
//                cpu?.queueIRQ()
                irqDelay = -1
            }
        }
        
        evenCycle = !evenCycle
    }
    
    private func stepFrame() {
        if framerateSwitch {
            switch cycle {
                case 1:
                    stepSweep()
                    stepLength()
                    
                    stepEnvelope()
                case 7459:
                    stepEnvelope()
                case 14915:
                    stepSweep()
                    stepLength()
                    
                    stepEnvelope()
                case 22373:
                    stepEnvelope()
                // Step 4 (29829) does nothing
                case 37282:
                    // 1 less than 1
                    cycle = 0
                default:
                    break
            }
            
        } else {
            switch cycle {
                case 7459:
                    stepEnvelope()
                case 14915:
                    stepSweep()
                    stepLength()
                    
                    stepEnvelope()
                case 22373:
                    stepEnvelope()
                case 29830:
                    setFrameIRQFlag()
                case 29831:
                    setFrameIRQFlag()
                    stepSweep()
                    stepLength()
                    
                    stepEnvelope()
                    
                    irqChanged()
                case 29832:
                    setFrameIRQFlag()
                case 37288:
                    // One less than 7458
                    cycle = 7458
                default:
                    break
            }
        }
        
        cycle += 1
    }
    
    private func stepEnvelope() {
        // Increment envelope (Square and Noise)
        square1.stepEnvelope()
        square2.stepEnvelope()
        triangle.stepLinear()
        noise.stepEnvelope()
    }
    
    private func stepSweep() {
        // Increment frequency sweep (Square)
        square1.stepSweep()
        square2.stepSweep()
    }
    
    private func stepLength() {
        // Increment length counters (all)
        square1.stepLength()
        square2.stepLength()
        triangle.stepLength()
        noise.stepLength()
    }
    
    private func setFrameIRQFlag() {
        if !disableIRQ {
            frameIRQ = true
        }
    }
    
    private func irqChanged() {
        if !disableIRQ && frameIRQ {
            irqDelay = 2
        }
    }
    
    func outputValue() -> Double {
        var square1: Double = 0
        var square2: Double = 0
        var triangle: Double = 0
        var noise: Double = 0
        var dmc: Double = 0
        
        if square1Enable {
            square1 = Double(self.square1.output())
        }
        
        if square2Enable {
            square2 = Double(self.square2.output())
        }
        
        if triangleEnable {
            triangle = self.triangle.output() / 8227
        }
        
        if noiseEnable {
            noise = Double(self.noise.output()) / 12241
        }
        
        if(self.dmcEnable) {
            dmc = Double(self.dmc.output()) / 22638
        }
        
        var square_out: Double = 0
        
        if(square1 + square2 != 0) {
            square_out = 95.88/(8128/(square1 + square2) + 100)
        }
        
        let tnd_out: Double = 159.79/(1/(triangle + noise + dmc) + 100)
        
        return square_out + tnd_out
    }
    
    // MARK: - APU Register Access
    
    func cpuWrite(_ address: UInt16, data: UInt8) {
        switch(address) {
            case 0x4000:
                square1.control = data
            case 0x4001:
                square1.sweep = data
            case 0x4002:
                square1.wavelengthLow = data
            case 0x4003:
                if square1Enable {
                    square1.lengthCounter = data
                }
            case 0x4004:
                square2.control = data
            case 0x4005:
                square2.sweep = data
            case 0x4006:
                square2.wavelengthLow = data
            case 0x4007:
                if square2Enable {
                    square2.lengthCounter = data
                }
            case 0x4008:
                triangle.control = data
            case 0x4009:
                break
            case 0x400A:
                triangle.wavelengthLow = data
            case 0x400B:
                if triangleEnable {
                    triangle.lengthCounter = data
                }
            case 0x400C:
                noise.control = data
            case 0x400D:
                break
            case 0x400E:
                noise.period = data
            case 0x400F:
                if noiseEnable {
                    noise.lengthCounter = data
                }
            case 0x4010:
                dmc.control = data
            case 0x4011:
                dmc.directLoad = data
            case 0x4012:
                dmc.address = data
            case 0x4013:
                dmc.sampleLength = data
             case 0x4015:
                control = data
            case 0x4017:
                timerControl = data
            default:
                break
        }
    }
    
    func cpuRead(_ address: UInt16) -> UInt8 {
        if address == 0x4015 {
            var temp: UInt8 = (square1.lengthCounterLoad == 0 || !square1Enable) ? 0 : 1
            temp |= (square2.lengthCounterLoad == 0 || !square2Enable) ? 0 : 0x2
            temp |= (triangle.lengthCounterLoad == 0 || !triangleEnable) ? 0 : 0x4
            temp |= (noise.lengthCounterLoad == 0 || !noiseEnable) ? 0 : 0x8
            temp |= (dmc.sampleLengthRemaining == 0 || !dmcEnable) ? 0 : 0x10
            
            temp |= frameIRQ ? 0x40 : 0
            frameIRQ = false
            
            temp |= (!dmc.dmcIRQ || !dmcEnable) ? 0 : 0x80
            
            return temp
        } else {
//            print(String(format: "Invalid read at %x", address))
        }
        
        return 0
    }
}


