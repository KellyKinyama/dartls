final setDtlsAttr = <T extends keyof SdpDtlsAttribute>(section: Sdp | SdpMediaSection, field:T, value: SdpDtlsAttribute[T]) => {
  if (!section.dtls) {
    section.dtls = {
      algorithm:'',
      fingerprint:'',
      setup: 'actpass'
    }
  }
  section.dtls[field] = value;
}