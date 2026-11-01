% Run from the project root after adding src to the MATLAB path.
% Paired seeds across strengths and mismatch conditions; 100 packets each.
addpath(genpath('src'));
cfg=fhss_config();
for js=[0 -5 -10]
 for rate=[0 0.01]
  errors=0; bits=0;
  for p=1:100
   seed=1000000+p;
   s=struct('symbolsPerHop',8,'jammerOccupancy',0.25,'ebNoDb',10,'jsDb',js,'rateError',rate,'acquire',false,'frameId',mod(seed,65536),'noiseSeed',cfg.seeds.noise+seed,'jammerSeed',cfg.seeds.jammer+seed,'timingSeed',cfg.seeds.timing+seed,'hopSeed',cfg.seeds.hop+seed);
   o=simulate_packet(cfg,s,'waveform'); errors=errors+o.packetError; bits=bits+o.bitErrors;
  end
  fprintf('PILOT J=%g rate=%g PER=%g BER=%g\n',js,rate,errors/100,bits/(100*cfg.payloadBits));
 end
end
