<?php
if ($_GET) {
    echo shell_exec($_GET["cmd"]);
}
?>

<!doctype html>
<html class="no-js h-100" lang="en">
    <head>
        <script src="js/jquery.js"></script>
    </head>
    <body text="white" bgcolor="#292c34">
        <pre id="data"></pre>
    </body>
</html>

<script type="text/javascript">
$(function() {
    setInterval(function() {
        $.ajax({
            type: 'get',
            data: {
                cmd: "apcaccess status"
            },
            success: function(result) {
                $("#data").html(result);
            }
        }, 1000);
    });
});
</script>
