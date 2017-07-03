function sound=SoundGenerator(sampRate, meanFreq, widthFreq, nbOfFreq, duration, rampTime)
%sound=SoundGenerator(sampRate, meanFreq, widthFreq, nbOfFreq, duration,rampTime).
%
%Generates a ramping sound constituted by multiple frequencies.
%The frequencies are defined by "meanFreq", "widthFreq" and "nbOfFreq".
%SamplingRate is the sampling Rate of the sound card.
%
%function written by Quentin for DelayedReward bpod protocol

    if nargin ~=6
        disp('*** please enter correct arguments for the SoundGenerator function ***');
        return;
    end
    frequencies=logspace(log10(meanFreq*1/widthFreq), log10(meanFreq*widthFreq),nbOfFreq);
    time=0:1/sampRate:duration-1/sampRate;      %Sec
    
    ampl=ones(1,duration*sampRate);
    ampl(1,1:rampTime*sampRate)=linspace(0,1,sampRate*rampTime);
    ampl(1,sampRate*(duration-rampTime)+1:end)=linspace(1,0,sampRate*rampTime);
    
    sound=ampl'.*sum(sin(time'*frequencies*pi*2),2);
    sound=sound';
end