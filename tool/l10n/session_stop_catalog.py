NEW_KEYS = (
    "liveStop", "liveStopping", "liveStopIdle", "liveStopUnconfirmed",
    "liveStopFailed", "liveStopEscapeHint",
)
COPY = {
    "en": ("Stop", "Stop requested…", "No active execution was interrupted.", "Stop not confirmed. Follow the live execution state.", "The stop request was refused.", "Press Escape again to stop."),
    "pt": ("Parar", "Interrupção solicitada…", "Nenhuma execução ativa foi interrompida.", "Interrupção não confirmada. Acompanhe o estado da execução ao vivo.", "O pedido de interrupção foi recusado.", "Pressione Escape de novo para parar."),
    "es": ("Detener", "Interrupción solicitada…", "No se interrumpió ninguna ejecución activa.", "Interrupción no confirmada. Observa el estado de ejecución en vivo.", "Se rechazó la solicitud de interrupción.", "Pulsa Escape de nuevo para detener."),
    "fr": ("Arrêter", "Arrêt demandé…", "Aucune exécution active n’a été interrompue.", "Arrêt non confirmé. Suivez l’état d’exécution en direct.", "La demande d’arrêt a été refusée.", "Appuyez à nouveau sur Échap pour arrêter."),
    "de": ("Stoppen", "Stopp angefordert…", "Keine aktive Ausführung wurde unterbrochen.", "Stopp nicht bestätigt. Verfolge den Live-Ausführungsstatus.", "Die Stoppanfrage wurde abgelehnt.", "Drücke Escape erneut zum Stoppen."),
    "it": ("Interrompi", "Interruzione richiesta…", "Nessuna esecuzione attiva è stata interrotta.", "Interruzione non confermata. Segui lo stato di esecuzione dal vivo.", "La richiesta di interruzione è stata rifiutata.", "Premi di nuovo Esc per interrompere."),
    "ru": ("Остановить", "Остановка запрошена…", "Ни одно активное выполнение не было прервано.", "Остановка не подтверждена. Следите за состоянием выполнения в реальном времени.", "Запрос остановки отклонён.", "Нажмите Escape ещё раз для остановки."),
    "ja": ("停止", "停止を要求しました…", "実行中の処理は中断されませんでした。", "停止を確認できません。ライブの実行状態を確認してください。", "停止要求が拒否されました。", "停止するにはもう一度 Esc を押してください。"),
    "ko": ("중지", "중지 요청됨…", "활성 실행이 중단되지 않았습니다.", "중지가 확인되지 않았습니다. 실시간 실행 상태를 확인하세요.", "중지 요청이 거부되었습니다.", "중지하려면 Escape를 다시 누르세요."),
    "zh": ("停止", "已请求停止…", "没有活动执行被中断。", "未确认停止。请关注实时执行状态。", "停止请求被拒绝。", "再次按 Escape 停止。"),
    "hi": ("रोकें", "रोकने का अनुरोध किया गया…", "कोई सक्रिय निष्पादन बाधित नहीं हुआ।", "रोकने की पुष्टि नहीं हुई। लाइव निष्पादन की स्थिति देखें।", "रोकने का अनुरोध अस्वीकार किया गया।", "रोकने के लिए Escape फिर दबाएँ।"),
    "bn": ("থামান", "থামানোর অনুরোধ করা হয়েছে…", "কোনো সক্রিয় কাজ বাধাগ্রস্ত হয়নি।", "থামানো নিশ্চিত হয়নি। সরাসরি কাজের অবস্থা দেখুন।", "থামানোর অনুরোধ প্রত্যাখ্যাত হয়েছে।", "থামাতে আবার Escape চাপুন।"),
    "ar": ("إيقاف", "طُلب الإيقاف…", "لم تتم مقاطعة أي تنفيذ نشط.", "لم يتأكد الإيقاف. تابع حالة التنفيذ المباشرة.", "رُفض طلب الإيقاف.", "اضغط Escape مرة أخرى للإيقاف."),
    "ur": ("روکیں", "روکنے کی درخواست کی گئی…", "کوئی فعال عمل نہیں روکا گیا۔", "روکنے کی تصدیق نہیں ہوئی۔ لائیو عمل کی حالت دیکھیں۔", "روکنے کی درخواست مسترد کر دی گئی۔", "روکنے کے لیے Escape دوبارہ دبائیں۔"),
}
