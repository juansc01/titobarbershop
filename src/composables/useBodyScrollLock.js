// Fixes the classic iOS Safari bug where the page behind a fixed modal
// keeps scrolling ("rubber-banding"), making the modal look frozen/cut.
let lockCount = 0
let savedScrollY = 0

export function lockBodyScroll() {
  if (typeof document === 'undefined') return

  if (lockCount === 0) {
    savedScrollY = window.scrollY || window.pageYOffset || 0
    document.body.style.top = `-${savedScrollY}px`
    document.body.classList.add('modal-open')
  }
  lockCount += 1
}

export function unlockBodyScroll() {
  if (typeof document === 'undefined') return
  if (lockCount === 0) return

  lockCount -= 1
  if (lockCount === 0) {
    document.body.classList.remove('modal-open')
    document.body.style.top = ''
    window.scrollTo(0, savedScrollY)
  }
}

export function useBodyScrollLock() {
  return { lockBodyScroll, unlockBodyScroll }
}

