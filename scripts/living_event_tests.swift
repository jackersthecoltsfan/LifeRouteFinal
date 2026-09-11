import Foundation
import Metal

@main struct LivingEventTests {
    static func main() throws {
        let args=CommandLine.arguments
        precondition(args.count==4,"metallib, event kind, output JSON")
        let device=MTLCreateSystemDefaultDevice()!,queue=device.makeCommandQueue()!
        let library=try device.makeLibrary(URL:URL(fileURLWithPath:args[1]))
        let function=args[2]=="bat" ? "livingBatEventProbe" : (args[2]=="bird" ? "livingBirdEventProbe" : "livingGustEventProbe")
        let pipeline=try device.makeComputePipelineState(function:library.makeFunction(name:function)!)
        func probe(_ requests:[SIMD2<Float>]) -> [SIMD4<Float>] {
            let input=device.makeBuffer(bytes:requests,length:requests.count*8,options:.storageModeShared)!
            let output=device.makeBuffer(length:requests.count*32,options:.storageModeShared)!
            let command=queue.makeCommandBuffer()!,encoder=command.makeComputeCommandEncoder()!
            encoder.setComputePipelineState(pipeline);encoder.setBuffer(input,offset:0,index:0);encoder.setBuffer(output,offset:0,index:1)
            encoder.dispatchThreads(MTLSize(width:requests.count,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:64,height:1,depth:1))
            encoder.endEncoding();command.commit();command.waitUntilCompleted();precondition(command.status == .completed)
            return Array(UnsafeBufferPointer(start:output.contents().assumingMemoryBound(to:SIMD4<Float>.self),count:requests.count*2))
        }
        var assertions=0
        func expect(_ yes:Bool,_ message:String){assertions+=1;precondition(yes,message)}
        let times=(0...9600).map{Float($0)/10}
        let rows=probe(times.map{SIMD2($0,1)})
        var report:[String:Any]=["event":args[2],"sampleSeconds":960,"stepSeconds":0.1,"gpu":device.name]
        if args[2]=="bat" || args[2]=="bird" {
            let bird=args[2]=="bird"
            let cycleLength:Float=bird ? 38 : 32, takeoff:Float=bird ? 1.5 : 1
            let flightEnd:Float=bird ? 8.5 : 10, duration:Float=bird ? 10 : 11
            var starts:[Float]=[]
            for cycle in 0..<30 {
                let base=Float(cycle)*cycleLength
                let origin=probe([SIMD2(base,1)])[0],start=origin.w
                starts.append(start)
                let offsets:[Float]=[-0.01,0.5,takeoff+0.01,flightEnd-0.01,flightEnd+0.5,duration+0.01]
                let event=probe(offsets.map{SIMD2(start+$0,1)})
                expect(stride(from:0,to:event.count,by:2).map{Int(event[$0].z)} == [0,1,2,2,3,0],"roost/takeoff/flight/landing/roost order")
                for boundary in [Float(0),takeoff,flightEnd,duration] {
                    let edge=probe([SIMD2(start+boundary-0.0001,1),SIMD2(start+boundary+0.0001,1)])
                    expect(hypot(edge[0].x-edge[2].x,edge[0].y-edge[2].y)<0.0002,"position continuous across event boundary")
                }
                let edge=probe([SIMD2(base+cycleLength-0.0001,1),SIMD2(base+cycleLength+0.0001,1)])
                expect(hypot(edge[0].x-edge[2].x,edge[0].y-edge[2].y)<0.0002,"no teleport between alternating roost cycles")
            }
            let rests=zip(starts,starts.dropFirst()).map{Double($1-$0-duration)}
            expect(rests.allSatisfy{(bird ? 12.0 : 10.0)...(bird ? 35.0 : 30.0) ~= $0},"natural uninterrupted rest duration stays inside scene bounds")
            let fraction=Double(stride(from:0,to:rows.count,by:2).filter{rows[$0].z==0}.count)/Double(times.count)
            expect(fraction>0.60 && fraction<0.80,"more runtime roosting than flying")
            expect(Set(starts.enumerated().map{Int(($0.element-Float($0.offset)*cycleLength)*100)}).count>10,"departure timing varies")
            expect(stride(from:0,to:rows.count,by:2).allSatisfy{rows[$0].x>=0.12 && rows[$0].x<=0.85 && rows[$0].y>=(bird ? 0.30 : 0.20) && rows[$0].y<=(bird ? 0.66 : 0.42)},"path stays inside bounded photographed canyon region")
            let calm=probe(times.map{SIMD2($0,0)})
            expect(stride(from:0,to:calm.count,by:2).allSatisfy{calm[$0].z==0 && calm[$0].x==calm[0].x && calm[$0].y==calm[0].y},"Reduce Motion remains at fixed rest")
            report["restingFraction"]=fraction;report["eventStarts"]=starts;report["roostDurations"]=rests
            report["takeoffSeconds"]=takeoff;report["flightSeconds"]=flightEnd-takeoff;report["landingSeconds"]=duration-flightEnd
        }
        if args[2]=="gust" {
            var starts:[Float]=[]
            for cycle in 0..<30 {
                let base=Float(cycle)*32,start=probe([SIMD2(base,1)])[0].w
                starts.append(start)
                let event=probe([-0.01,0.5,4.99,5.5,6.51].map{SIMD2(start+$0,1)})
                expect(stride(from:0,to:event.count,by:2).map{Int(event[$0].z)} == [0,1,1,2,0],"steady/gust/settle/steady order")
                for boundary:Float in [0,1,5,6.5] {
                    let edge=probe([SIMD2(start+boundary-0.0001,1),SIMD2(start+boundary+0.0001,1)])
                    expect(abs(edge[0].x-edge[2].x)<0.001 && abs(edge[0].y-edge[2].y)<0.0001,"continuous wind strength and integrated travel")
                }
                let wrap=probe([SIMD2(base+31.9999,1),SIMD2(base+32.0001,1)])
                expect(abs(wrap[0].y-wrap[2].y)<0.0001,"wind never resets displacement between slots")
            }
            let intervals=zip(starts,starts.dropFirst()).map{Double($1-$0)}
            expect(intervals.allSatisfy{20...45 ~= $0},"natural gust interval20-45s")
            let active=Double(stride(from:0,to:rows.count,by:2).filter{rows[$0].z>0}.count)/Double(times.count)
            expect(active>0.15 && active<0.25,"gusts are episodic, not continuous")
            expect(stride(from:0,to:rows.count-2,by:2).allSatisfy{rows[$0+2].y>=rows[$0].y-0.00001},"integrated snow travel never runs backward")
            let calm=probe(times.map{SIMD2($0,0)})
            expect(calm.allSatisfy{$0 == .zero},"Reduce Motion suppresses gust state contribution")
            report["eventStarts"]=starts;report["intervals"]=intervals;report["gustSeconds"]=5;report["settleSeconds"]=1.5;report["activeFraction"]=active
        }
        report["assertions"]=assertions
        report["samples"]=times.enumerated().map{ i,t in ["time":t,"x":rows[i*2].x,"y":rows[i*2].y,"state":rows[i*2].z,"eventStart":rows[i*2].w,"extra0":rows[i*2+1].x,"extra1":rows[i*2+1].y,"extra2":rows[i*2+1].z,"extra3":rows[i*2+1].w] }
        try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:args[3]))
        print("PASS: \(args[2]) \(assertions) production GPU state assertions")
    }
}
