/* Independent unbounded-integer references derived from C11/C13/C14/C15 mathematical contracts. No RTL is parsed; no DUT intermediate is used. */
export const nearest=(n,d)=>{n=BigInt(n);d=BigInt(d);return n<0n?-((-n+d/2n)/d):(n+d/2n)/d;};
export const clamp=(n,lo,hi)=>n<lo?lo:n>hi?hi:n;
export const decode=(raw)=>8n*(BigInt(raw)>>4n)+(BigInt(raw)&7n)+((BigInt(raw)&8n)?4n:-4n);
export const calibration=(raw,weights,offset)=>{let n=BigInt(offset);for(let j=0;j<10;j++)if(BigInt(raw)&(1n<<BigInt(j)))n+=BigInt(weights[j]);let r=nearest(n,65536n);return {rounded:r,value:clamp(r,-2048n,2047n),low:r< -2048n,high:r>2047n};};
export const overlap=(s1,raw2)=>{let acc=(2n*BigInt(s1)-511n)*3533837n+(2n*decode(raw2)-512n)*54143n;let r=nearest(acc,131072n);return {acc,rounded:r,value:clamp(r,-16384n,16383n),sat:r< -16384n||r>16383n};};
export const reconstruction=(s1,d2,gain,offset)=>{let acc=(2n*BigInt(s1)-511n)*3533837n+(2n*BigInt(d2)-512n)*BigInt(gain)+2n*BigInt(offset);let r=nearest(acc,131072n);return {acc,rounded:r,value:clamp(r,-16384n,16383n),low:r< -16384n,high:r>16383n};};
export const recovery=(s1,fine,dc,gain9,gain15)=>{let ca=(2n*BigInt(s1)-511n)*3533837n+2n*BigInt(dc)*BigInt(gain9);let fa=BigInt(fine)*131072n+2n*BigInt(dc)*BigInt(gain15);let cr=nearest(ca,131072n),fr=nearest(fa,131072n);return {coarseAcc:ca,fineAcc:fa,coarseRounded:cr,fineRounded:fr,coarse:clamp(cr,-8388608n,8388607n),fine:clamp(fr,-8388608n,8388607n),coarseLow:cr< -8388608n,coarseHigh:cr>8388607n,fineLow:fr< -8388608n,fineHigh:fr>8388607n};};
