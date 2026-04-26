<?php
if ($_GET) {
    echo shell_exec("apcaccess status");
    return;
}
?>

<!doctype html>
<html class="no-js h-100" lang="en">
    <style>
    /* Общие стили */
    body {
      font-family: sans-serif;
      margin: 0;
    }

    /* Стили для навигационной панели (navbar) */
    .navbar {
      background-color: #333;
      overflow: hidden;
    }

    .navbar a {
      float: left;
      display: block;
      color: white;
      text-align: center;
      padding: 14px 16px;
      text-decoration: none;
      cursor: pointer; /* Меняем курсор на руку */
    }

    .navbar a:hover {
      background-color: #ddd;
      color: black;
    }

    /* Стили для контента вкладок */
    .tabcontent {
      display: none; /* Скрываем контент по умолчанию */
      padding: 20px;
      border: 1px solid #ccc;
      border-top: none; /* Убираем верхнюю границу, чтобы она соединялась с navbar */
    }

    /* Стили для активной вкладки (отображаемой) */
    .tabcontent.active {
      display: block;
    }

    /* Таблица внутри контента */
    table {
      border-collapse: collapse;
      width: 100%;
    }

    th, td {
      border: 1px solid black;
      padding: 8px;
      text-align: left;
    }

    th {
      background-color: #f2f2f2;
    }
    </style>

    <head>
        <script src="js/jquery.js"></script>
    </head>
    <div class="navbar">
        <a onclick="openTab('tab1')">Current values</a>
        <a onclick="openTab('tab2')">Description</a>
    </div>

    <body text="white" bgcolor="#292c34">
        <div id="tab1" class="tabcontent active">
            <pre id="data"></pre>
        </div>
        <div id="tab2" class="tabcontent">
            <table>
              <thead>
                <tr>
                  <th>Поле</th>
                  <th>Описание</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td>APC</td>
                  <td>Три числа, идентифицирующие версию протокола APC, версию микропрограммы или другие внутренние параметры. Значение не всегда документировано и может зависеть от конкретной модели UPS.</td>
                </tr>
                <tr>
                  <td>DATE</td>
                  <td>Текущая дата и время, полученные от UPS. Формат: YYYY-MM-DD HH:MM:SS +TZ (год-месяц-день часы:минуты:секунды + часовой пояс).</td>
                </tr>
                <tr>
                  <td>HOSTNAME</td>
                  <td>Имя хоста компьютера, с которого было запрошено состояние UPS.</td>
                </tr>
                <tr>
                  <td>VERSION</td>
                  <td>Версия программного обеспечения (например, apcupsd) на компьютере, которое собирает данные с UPS.</td>
                </tr>
                <tr>
                  <td>UPSNAME</td>
                  <td>Имя, присвоенное UPS. Может совпадать с именем хоста или быть другим.</td>
                </tr>
                <tr>
                  <td>CABLE</td>
                  <td>Тип кабеля, используемого для подключения UPS к компьютеру.</td>
                </tr>
                <tr>
                  <td>DRIVER</td>
                  <td>Имя драйвера, используемого для связи с UPS.</td>
                </tr>
                <tr>
                  <td>UPSMODE</td>
                  <td>Режим работы UPS. Stand Alone означает, что UPS работает независимо и не является частью кластера или сети.</td>
                </tr>
                <tr>
                  <td>STARTTIME</td>
                  <td>Дата и время запуска UPS (или когда apcupsd начал взаимодействовать с UPS).</td>
                </tr>
                <tr>
                  <td>MODEL</td>
                  <td>Модель UPS.</td>
                </tr>
                <tr>
                  <td>STATUS</td>
                  <td>Текущий статус UPS. ONLINE означает, что UPS работает от сети переменного тока. Другие возможные статусы: ONBATT (работа от батареи), OVERLOADED (перегрузка) и т.д.</td>
                </tr>
                <tr>
                  <td>LINEV</td>
                  <td>Входное напряжение переменного тока (напряжение в сети), измеренное UPS.</td>
                </tr>
                <tr>
                  <td>LOADPCT</td>
                  <td>Процент нагрузки UPS. Показывает, сколько мощности потребляет подключенное оборудование по отношению к максимальной мощности UPS.</td>
                </tr>
                <tr>
                  <td>BCHARGE</td>
                  <td>Уровень заряда батареи UPS в процентах.</td>
                </tr>
                <tr>
                  <td>TIMELEFT</td>
                  <td>Приблизительное время работы от батареи в минутах, если произойдет отключение электроэнергии. Этот показатель зависит от текущей нагрузки.</td>
                </tr>
                <tr>
                  <td>MBATTCHG</td>
                  <td>Минимальный уровень заряда батареи (в процентах), необходимый для возобновления питания от сети после отключения электроэнергии.</td>
                </tr>
                <tr>
                  <td>MINTIMEL</td>
                  <td>Минимальное время работы от батареи (в минутах), которое UPS должен обеспечить перед выключением. Это позволяет корректно завершить работу подключенному оборудованию.</td>
                </tr>
                <tr>
                  <td>MAXTIME</td>
                  <td>Максимальное врÐµмя работы от батареи (в секундах). Если UPS работает от батареи дольше этого времени, он принудительно выключится.</td>
                </tr>
                <tr>
                  <td>SENSE</td>
                  <td>Чувствительность UPS к колебаниям напряжения в сети. High означает, что UPS более чувствителен и чаще переключается на батарею. Возможные значения: High, Medium, Low.</td>
                </tr>
                <tr>
                  <td>LOTRANS</td>
                  <td>Нижний порог напряжения (в вольтах), при котором UPS переключается на питание от батареи из-за низкого входного напряжения.</td>
                </tr>
                <tr>
                  <td>HITRANS</td>
                  <td>Верхний порог напряжения (в вольтах), при котором UPS переключается на питание от батареи из-за высокого входного напряжения.</td>
                </tr>
                <tr>
                  <td>ALARMDEL</td>
                  <td>Задержка (в секундах) перед включением звукового сигнала (тревоги) при переходе на питание от батареи.</td>
                </tr>
                <tr>
                  <td>BATTV</td>
                  <td>Напряжение батареи UPS.</td>
                </tr>
                <tr>
                  <td>LASTXFER</td>
                  <td>Описание последней причины перехода на питание от батареи.</td>
                </tr>
                <tr>
                  <td>NUMXFERS</td>
                  <td>Общее количество переходов на питание от батареи с момента запуска UPS.</td>
                </tr>
                <tr>
                  <td>TONBATT</td>
                  <td>Время (в секундах), в течение которого UPS работал от батареи во время последнего перехода.</td>
                </tr>
                <tr>
                  <td>CUMONBATT</td>
                  <td>Общее время (в секундах), в течение которого UPS работал от батареи с момента запуска.</td>
                </tr>
                <tr>
                  <td>XOFFBATT</td>
                  <td>Дата и время последнего перехода обратно на питание от сети после работы от батареи. N/A означает, что такого перехода не было.</td>
                </tr>
                <tr>
                  <td>SELFTEST</td>
                  <td>Результат последнего самотестирования UPS. NO означает, что самотестирование не проводилось или не было пройдено успешно.</td>
                </tr>
                <tr>
                  <td>STATFLAG</td>
                  <td>Шестнадцатеричный код, представляющий различные флаги состояния UPS. Требуется более детальная документация для расшифровки каждого бита.</td>
                </tr>
                <tr>
                  <td>SERIALNO</td>
                  <td>Серийный номер UPS.</td>
                </tr>
                <tr>
                  <td>BATTDATE</td>
                  <td>Дата производства батареи UPS.</td>
                </tr>
                <tr>
                  <td>NOMINV</td>
                  <td>Номинальное входное напряжение переменного тока UPS.</td>
                </tr>
                <tr>
                  <td>NOMBATTV</td>
                  <td>Номинальное напряжение батареи UPS.</td>
                </tr>
                <tr>
                  <td>NOMPOWER</td>
                  <td>Номинальная мощность UPS в ваттах. Это максимальная мощность, которую UPS может обеспечить.</td>
                </tr>
                <tr>
                  <td>FIRMWARE</td>
                  <td>Версия прошивки UPS.</td>
                </tr>
                <tr>
                  <td>END APC</td>
                  <td>Метка, обозначающая конец блока информации APC. Содержит ту же дату и время, что и поле DATE.</td>
                </tr>
              </tbody>
            </table>
        </div>
    </body>
</html>


<script type="text/javascript">
(function load_data() {
    $.ajax({
        type: 'get',
        data: { cmd: "" },
        success: function(result) {
            $("#data").text(result);
            setTimeout(load_data, 1000);
        },
        timeout: function(result) {
            $("#data").text(result);
            setTimeout(load_data, 1000);
        },
        error: function(result) {
            $("#data").text(result);
            setTimeout(load_data, 1000);
        }
    });
})();
function openTab(tabId) {
  // Сначала убираем класс "active" у всех вкладок и контента
  var tabcontents = document.getElementsByClassName("tabcontent");
  for (var i = 0; i < tabcontents.length; i++) {
    tabcontents[i].classList.remove("active");
  }

  var navLinks = document.getElementsByClassName("navbar")[0].getElementsByTagName("a");
    for (var i = 0; i < navLinks.length; i++) {
        navLinks[i].classList.remove("active");
    }

  // Затем добавляем класс "active" к выбранной вкладке и ее контенту
  document.getElementById(tabId).classList.add("active");
   // Активируем ссылку navbar
   for (var i = 0; i < navLinks.length; i++) {
        if (navLinks[i].getAttribute("onclick") === "openTab('" + tabId + "')") {
            navLinks[i].classList.add("active");
            break;
        }
    }
}
</script>
