document.addEventListener('DOMContentLoaded', function () {
    // ---- URL search bar ----
    var urlInput = document.getElementById('url-input');
    var goBtn = document.getElementById('go-btn');

    function navigateToUrl() {
        var value = (urlInput.value || '').trim();
        if (!value) {
            return;
        }
        // Auto-add protocol if missing
        if (!/^https?:\/\//i.test(value)) {
            value = 'https://' + value;
        }
        window.location.href = value;
    }

    if (urlInput) {
        urlInput.addEventListener('keydown', function (e) {
            if (e.key === 'Enter') {
                e.preventDefault();
                navigateToUrl();
            }
        });
    }
    if (goBtn) {
        goBtn.addEventListener('click', function (e) {
            e.preventDefault();
            navigateToUrl();
        });
    }

    // ---- Portal cards ----
    var cards = Array.prototype.slice.call(
        document.querySelectorAll('.portal-card[href]')
    );

    if (cards.length === 0) {
        return;
    }

    // Click handlers
    cards.forEach(function (card) {
        card.addEventListener('click', function () {
            var href = card.getAttribute('href');
            if (href) {
                window.location.href = href;
            }
        });
    });

    // Keyboard navigation
    var focusedIndex = -1;

    function focusCard(index) {
        if (index < 0) {
            index = cards.length - 1;
        }
        if (index >= cards.length) {
            index = 0;
        }
        focusedIndex = index;
        cards[focusedIndex].focus();
    }

    cards.forEach(function (card, i) {
        card.setAttribute('tabindex', '0');

        card.addEventListener('focus', function () {
            focusedIndex = i;
        });

        card.addEventListener('keydown', function (e) {
            switch (e.key) {
                case 'ArrowRight':
                case 'ArrowDown':
                    e.preventDefault();
                    focusCard(focusedIndex + 1);
                    break;
                case 'ArrowLeft':
                case 'ArrowUp':
                    e.preventDefault();
                    focusCard(focusedIndex - 1);
                    break;
                case 'Enter':
                    e.preventDefault();
                    var href = card.getAttribute('href');
                    if (href) {
                        window.location.href = href;
                    }
                    break;
            }
        });
    });
});
