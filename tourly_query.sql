-- Tạo cơ sở dữ liệu
CREATE DATABASE Tourly;
GO

USE Tourly;
GO

-- Tạo bảng Vai trò
CREATE TABLE VaiTro (
    MaVaiTro INT PRIMARY KEY IDENTITY(1,1),
    TenVaiTro NVARCHAR(50) NOT NULL,
    MoTa NVARCHAR(200)
);

-- Tạo bảng Người dùng
CREATE TABLE NguoiDung (
    MaNguoiDung INT PRIMARY KEY IDENTITY(1,1),
    TenDangNhap NVARCHAR(50) NOT NULL UNIQUE,
    MatKhau NVARCHAR(100) NOT NULL,
    HoTen NVARCHAR(100) NOT NULL,
    Email NVARCHAR(100) NOT NULL UNIQUE,
    SoDienThoai NVARCHAR(20),
    DiaChi NVARCHAR(200),
    MaVaiTro INT NOT NULL,
    TrangThai BIT DEFAULT 1,
    NgayTao DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (MaVaiTro) REFERENCES VaiTro(MaVaiTro)
);



-- Tạo bảng Tour
CREATE TABLE Tour (
    MaTour INT PRIMARY KEY IDENTITY(1,1),
    TenTour NVARCHAR(100) NOT NULL,
    MoTa NVARCHAR(MAX),
    DiemKhoiHanh NVARCHAR(100) NOT NULL,
    DiemDen NVARCHAR(100) NOT NULL,
    NgayKhoiHanh DATETIME NOT NULL,
    NgayKetThuc DATETIME NOT NULL,
    SoNguoiToiDa INT NOT NULL,
    Gia DECIMAL(18,2) NOT NULL,
    TrangThai NVARCHAR(20) DEFAULT 'Active',
    DuongDanAnh NVARCHAR(200),
    NguoiTao INT,
    NgayTao DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (NguoiTao) REFERENCES NguoiDung(MaNguoiDung)
);

-- Tạo bảng Đặt tour
CREATE TABLE DatTour (
    MaDatTour INT PRIMARY KEY IDENTITY(1,1),
    MaTour INT NOT NULL,
    MaNguoiDung INT NOT NULL,
    SoNguoi INT NOT NULL,
    TongTien DECIMAL(18,2) NOT NULL,
    TrangThai NVARCHAR(20) DEFAULT 'Pending',
    NgayTao DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (MaTour) REFERENCES Tour(MaTour),
    FOREIGN KEY (MaNguoiDung) REFERENCES NguoiDung(MaNguoiDung)
);

-- Tạo bảng Thanh toán
CREATE TABLE ThanhToan (
    MaThanhToan INT PRIMARY KEY IDENTITY(1,1),
    MaDatTour INT NOT NULL,
    SoTien DECIMAL(18,2) NOT NULL,
    PhuongThucThanhToan NVARCHAR(50) NOT NULL,
    NgayThanhToan DATETIME DEFAULT GETDATE(),
    TrangThai NVARCHAR(20) DEFAULT 'Pending',
    FOREIGN KEY (MaDatTour) REFERENCES DatTour(MaDatTour)
);

-- Tạo bảng Đánh giá
CREATE TABLE DanhGia (
    MaDanhGia INT PRIMARY KEY IDENTITY(1,1),
    MaTour INT NOT NULL,
    MaNguoiDung INT NOT NULL,
    Diem INT NOT NULL CHECK (Diem BETWEEN 1 AND 5),
    NoiDung NVARCHAR(MAX),
    NgayDanhGia DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (MaTour) REFERENCES Tour(MaTour),
    FOREIGN KEY (MaNguoiDung) REFERENCES NguoiDung(MaNguoiDung),
    UNIQUE (MaTour, MaNguoiDung)
);

-- Tạo trigger kiểm tra số lượng người tham gia tour
CREATE TRIGGER trg_KiemTraSoNguoi
ON DatTour
AFTER INSERT, UPDATE
AS
BEGIN
    DECLARE @MaTour INT, @SoNguoi INT, @SoNguoiToiDa INT
    
    SELECT @MaTour = MaTour, @SoNguoi = SoNguoi
    FROM inserted
    
    SELECT @SoNguoiToiDa = SoNguoiToiDa
    FROM Tour
    WHERE MaTour = @MaTour
    
    IF @SoNguoi > @SoNguoiToiDa
    BEGIN
        RAISERROR('Số lượng người tham gia vượt quá giới hạn của tour', 16, 1)
        ROLLBACK TRANSACTION
    END
END;

-- Tạo trigger tự động tạo thanh toán khi đặt tour
CREATE TRIGGER trg_TaoThanhToan
ON DatTour
AFTER INSERT
AS
BEGIN
    INSERT INTO ThanhToan (MaDatTour, SoTien, PhuongThucThanhToan)
    SELECT MaDatTour, TongTien, N'Tiền mặt'
    FROM inserted
END;


-- Trigger kiểm tra định dạng email
CREATE TRIGGER trg_KiemTraEmail
ON NguoiDung
AFTER INSERT, UPDATE
AS
BEGIN
    -- Kiểm tra định dạng email bằng LIKE
    -- Email phải có dạng: text@domain.com
    IF EXISTS (
        SELECT 1 
        FROM inserted 
        WHERE Email NOT LIKE '%_@%_._%'
        OR Email LIKE '@%'
        OR Email LIKE '%@%@%'
    )
    BEGIN
        RAISERROR(N'Email không đúng định dạng. Email phải có dạng: example@domain.com', 16, 1)
        ROLLBACK TRANSACTION
        RETURN
    END
END;

-- Trigger kiểm tra định dạng số điện thoại
CREATE TRIGGER trg_KiemTraSoDienThoai
ON NguoiDung
AFTER INSERT, UPDATE
AS
BEGIN
    -- Kiểm tra số điện thoại:
    -- 1. Phải là số
    -- 2. Độ dài từ 10-11 số
    -- 3. Bắt đầu bằng số 0
    IF EXISTS (
        SELECT 1 
        FROM inserted 
        WHERE SoDienThoai IS NOT NULL
        AND (
            SoDienThoai NOT LIKE '0%'
            OR LEN(SoDienThoai) NOT BETWEEN 10 AND 11
            OR SoDienThoai LIKE '%[^0-9]%'
        )
    )
    BEGIN
        RAISERROR(N'Số điện thoại không hợp lệ. Số điện thoại phải bắt đầu bằng số 0 và có 10-11 chữ số', 16, 1)
        ROLLBACK TRANSACTION
        RETURN
    END
END;


-- Trigger kiểm tra đánh giá
CREATE TRIGGER trg_KiemTraDanhGia
ON DanhGia
AFTER INSERT, UPDATE
AS
BEGIN
    -- Kiểm tra xem khách hàng đã đánh giá tour này chưa
    IF EXISTS (
        SELECT 1
        FROM DanhGia dg
        JOIN inserted i ON dg.MaTour = i.MaTour 
            AND dg.MaNguoiDung = i.MaNguoiDung
        WHERE dg.MaDanhGia != i.MaDanhGia
    )
    BEGIN
        RAISERROR(N'Bạn đã đánh giá tour này rồi. Mỗi khách hàng chỉ được đánh giá một lần cho mỗi tour!', 16, 1)
        ROLLBACK TRANSACTION
        RETURN
    END

    -- Kiểm tra xem khách hàng đã hoàn thành tour chưa
    IF NOT EXISTS (
        SELECT 1
        FROM DatTour dt
        JOIN ThanhToan tt ON dt.MaDatTour = tt.MaDatTour
        JOIN inserted i ON dt.MaTour = i.MaTour 
            AND dt.MaNguoiDung = i.MaNguoiDung
        WHERE tt.TrangThai = 'Completed'
    )
    BEGIN
        RAISERROR(N'Bạn chỉ có thể đánh giá tour sau khi đã hoàn thành và thanh toán!', 16, 1)
        ROLLBACK TRANSACTION
        RETURN
    END
END;


-- Trigger kiểm tra tên tour
CREATE TRIGGER trg_KiemTraTenTour
ON Tour
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM inserted 
        WHERE TenTour IS NULL OR LEN(LTRIM(RTRIM(TenTour))) = 0
    )
    BEGIN
        RAISERROR(N'Tên tour không được để trống', 16, 1)
        ROLLBACK TRANSACTION
        RETURN
    END
END;

-- Trigger kiểm tra điểm khởi hành và điểm đến
CREATE TRIGGER trg_KiemTraDiemKhoiHanhDen
ON Tour
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM inserted 
        WHERE DiemKhoiHanh IS NULL 
        OR DiemDen IS NULL 
        OR LEN(LTRIM(RTRIM(DiemKhoiHanh))) = 0 
        OR LEN(LTRIM(RTRIM(DiemDen))) = 0
    )
    BEGIN
        RAISERROR(N'Điểm khởi hành và điểm đến không được để trống', 16, 1)
        ROLLBACK TRANSACTION
        RETURN
    END
END;

-- Trigger kiểm tra ngày khởi hành
CREATE TRIGGER trg_KiemTraNgayKhoiHanh
ON Tour
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM inserted 
        WHERE NgayKhoiHanh <= GETDATE()
    )
    BEGIN
        RAISERROR(N'Ngày khởi hành phải lớn hơn ngày hiện tại', 16, 1)
        ROLLBACK TRANSACTION
        RETURN
    END
END;

-- Trigger kiểm tra ngày kết thúc
CREATE TRIGGER trg_KiemTraNgayKetThuc
ON Tour
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM inserted 
        WHERE NgayKetThuc <= NgayKhoiHanh
    )
    BEGIN
        RAISERROR(N'Ngày kết thúc phải lớn hơn ngày khởi hành', 16, 1)
        ROLLBACK TRANSACTION
        RETURN
    END
END;

-- Trigger kiểm tra số người tối đa
CREATE TRIGGER trg_KiemTraSoNguoiToiDa
ON Tour
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM inserted 
        WHERE SoNguoiToiDa <= 0
    )
    BEGIN
        RAISERROR(N'Số người tối đa phải lớn hơn 0', 16, 1)
        ROLLBACK TRANSACTION
        RETURN
    END
END;

-- Trigger kiểm tra giá tour
CREATE TRIGGER trg_KiemTraGiaTour
ON Tour
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM inserted 
        WHERE Gia <= 0
    )
    BEGIN
        RAISERROR(N'Giá tour phải lớn hơn 0', 16, 1)
        ROLLBACK TRANSACTION
        RETURN
    END
END;


-- Procedure tạo tour (Dành cho nhân viên)
CREATE PROCEDURE sp_TaoTour
    @TenTour NVARCHAR(100),
    @MoTa NVARCHAR(MAX),
    @DiemKhoiHanh NVARCHAR(100),
    @DiemDen NVARCHAR(100),
    @NgayKhoiHanh DATETIME,
    @NgayKetThuc DATETIME,
    @SoNguoiToiDa INT,
    @Gia DECIMAL(18,2),
    @DuongDanAnh NVARCHAR(200),
    @NguoiTao INT
AS
BEGIN
    -- Chỉ kiểm tra quyền hạn người tạo
    DECLARE @VaiTro INT
    SELECT @VaiTro = MaVaiTro 
    FROM NguoiDung 
    WHERE MaNguoiDung = @NguoiTao

    IF @VaiTro NOT IN (1, 2) -- 1: Admin, 2: Staff
    BEGIN
        RAISERROR(N'Bạn không có quyền tạo tour mới', 16, 1)
        RETURN
    END

    -- Thêm tour mới (các trigger sẽ tự động kiểm tra các điều kiện)
    INSERT INTO Tour (
        TenTour,
        MoTa,
        DiemKhoiHanh,
        DiemDen,
        NgayKhoiHanh,
        NgayKetThuc,
        SoNguoiToiDa,
        Gia,
        DuongDanAnh,
        NguoiTao,
        TrangThai
    )
    VALUES (
        @TenTour,
        @MoTa,
        @DiemKhoiHanh,
        @DiemDen,
        @NgayKhoiHanh,
        @NgayKetThuc,
        @SoNguoiToiDa,
        @Gia,
        @DuongDanAnh,
        @NguoiTao,
        'Active'
    )

    -- Trả về ID của tour vừa tạo
    SELECT SCOPE_IDENTITY() AS MaTour
END;


-- Procedure sửa tour
CREATE PROCEDURE sp_SuaTour
    @MaTour INT,
    @TenTour NVARCHAR(100),
    @MoTa NVARCHAR(MAX),
    @DiemKhoiHanh NVARCHAR(100),
    @DiemDen NVARCHAR(100),
    @NgayKhoiHanh DATETIME,
    @NgayKetThuc DATETIME,
    @SoNguoiToiDa INT,
    @Gia DECIMAL(18,2),
    @DuongDanAnh NVARCHAR(200),
    @NguoiSua INT
AS
BEGIN
    -- Kiểm tra quyền hạn
    IF NOT EXISTS (
        SELECT 1 FROM NguoiDung 
        WHERE MaNguoiDung = @NguoiSua 
        AND MaVaiTro IN (1, 2)
    )
    BEGIN
        RAISERROR(N'Bạn không có quyền sửa thông tin tour', 16, 1)
        RETURN
    END

    -- Kiểm tra tour có tồn tại không
    IF NOT EXISTS (SELECT 1 FROM Tour WHERE MaTour = @MaTour)
    BEGIN
        RAISERROR(N'Tour không tồn tại', 16, 1)
        RETURN
    END

    -- Kiểm tra tour đã có người đặt chưa
    IF EXISTS (
        SELECT 1 FROM DatTour 
        WHERE MaTour = @MaTour 
        AND TrangThai NOT IN ('Cancelled', 'Completed')
    )
    BEGIN
        RAISERROR(N'Không thể sửa thông tin tour đã có người đặt', 16, 1)
        RETURN
    END

    -- Cập nhật thông tin tour
    UPDATE Tour
    SET TenTour = @TenTour,
        MoTa = @MoTa,
        DiemKhoiHanh = @DiemKhoiHanh,
        DiemDen = @DiemDen,
        NgayKhoiHanh = @NgayKhoiHanh,
        NgayKetThuc = @NgayKetThuc,
        SoNguoiToiDa = @SoNguoiToiDa,
        Gia = @Gia,
        DuongDanAnh = @DuongDanAnh
    WHERE MaTour = @MaTour

    -- Trả về thông tin tour sau khi cập nhật
    SELECT * FROM Tour WHERE MaTour = @MaTour
END
GO

-- Procedure xóa tour
CREATE PROCEDURE sp_XoaTour
    @MaTour INT,
    @NguoiXoa INT
AS
BEGIN
    -- Kiểm tra quyền hạn
    IF NOT EXISTS (
        SELECT 1 FROM NguoiDung 
        WHERE MaNguoiDung = @NguoiXoa 
        AND MaVaiTro IN (1, 2)
    )
    BEGIN
        RAISERROR(N'Bạn không có quyền xóa tour', 16, 1)
        RETURN
    END

    -- Kiểm tra tour có tồn tại không
    IF NOT EXISTS (SELECT 1 FROM Tour WHERE MaTour = @MaTour)
    BEGIN
        RAISERROR(N'Tour không tồn tại', 16, 1)
        RETURN
    END

    -- Kiểm tra tour đã có người đặt chưa
    IF EXISTS (
        SELECT 1 FROM DatTour 
        WHERE MaTour = @MaTour 
        AND TrangThai NOT IN ('Cancelled', 'Completed')
    )
    BEGIN
        RAISERROR(N'Không thể xóa tour đã có người đặt', 16, 1)
        RETURN
    END

    -- Cập nhật trạng thái tour thành 'Inactive'
    UPDATE Tour
    SET TrangThai = 'Inactive'
    WHERE MaTour = @MaTour

    -- Trả về thông báo thành công
    SELECT N'Đã xóa tour thành công' AS Message
END
GO

-- Tạo procedure tìm kiếm tour
CREATE PROCEDURE sp_TimKiemTour
    @TuKhoa NVARCHAR(100) = NULL,
    @GiaThap DECIMAL(18,2) = NULL,
    @GiaCao DECIMAL(18,2) = NULL,
    @NgayKhoiHanh DATETIME = NULL,
    @DiemDen NVARCHAR(100) = NULL
AS
BEGIN
    SELECT *
    FROM Tour
    WHERE (@TuKhoa IS NULL OR TenTour LIKE '%' + @TuKhoa + '%' OR MoTa LIKE '%' + @TuKhoa + '%')
    AND (@GiaThap IS NULL OR Gia >= @GiaThap)
    AND (@GiaCao IS NULL OR Gia <= @GiaCao)
    AND (@NgayKhoiHanh IS NULL OR NgayKhoiHanh >= @NgayKhoiHanh)
    AND (@DiemDen IS NULL OR DiemDen LIKE '%' + @DiemDen + '%')
    AND TrangThai = 'Active'
END;

-- Procedure đăng ký tài khoản khách hàng
CREATE PROCEDURE sp_DangKyTaiKhoan
    @TenDangNhap NVARCHAR(50),
    @MatKhau NVARCHAR(100),
    @HoTen NVARCHAR(100),
    @Email NVARCHAR(100),
    @SoDienThoai NVARCHAR(20) = NULL,
    @DiaChi NVARCHAR(200) = NULL
AS
BEGIN
    -- Kiểm tra tên đăng nhập đã tồn tại chưa
    IF EXISTS (SELECT 1 FROM NguoiDung WHERE TenDangNhap = @TenDangNhap)
    BEGIN
        RAISERROR('Tên đăng nhập đã tồn tại', 16, 1)
        RETURN
    END

    -- Kiểm tra email đã tồn tại chưa
    IF EXISTS (SELECT 1 FROM NguoiDung WHERE Email = @Email)
    BEGIN
        RAISERROR('Email đã tồn tại', 16, 1)
        RETURN
    END

    -- Thêm tài khoản mới
    INSERT INTO NguoiDung (TenDangNhap, MatKhau, HoTen, Email, SoDienThoai, DiaChi, MaVaiTro)
    VALUES (@TenDangNhap, @MatKhau, @HoTen, @Email, @SoDienThoai, @DiaChi, 3) -- 3 là mã vai trò Customer
END;


-- Procedure sửa thông tin người dùng
CREATE PROCEDURE sp_SuaNguoiDung
    @MaNguoiDung INT,
    @HoTen NVARCHAR(100),
    @Email NVARCHAR(100),
    @SoDienThoai NVARCHAR(20),
    @DiaChi NVARCHAR(200),
    @MaVaiTro INT = NULL,
    @TrangThai BIT = NULL,
    @NguoiSua INT
AS
BEGIN
    -- Kiểm tra người dùng tồn tại
    IF NOT EXISTS (SELECT 1 FROM NguoiDung WHERE MaNguoiDung = @MaNguoiDung)
    BEGIN
        RAISERROR(N'Người dùng không tồn tại', 16, 1)
        RETURN
    END

    -- Lấy thông tin vai trò của người sửa
    DECLARE @VaiTroNguoiSua INT
    SELECT @VaiTroNguoiSua = MaVaiTro 
    FROM NguoiDung 
    WHERE MaNguoiDung = @NguoiSua

    -- Kiểm tra quyền hạn
    -- Nếu không phải Admin và đang cố gắng sửa thông tin của người khác
    IF @VaiTroNguoiSua != 1 AND @MaNguoiDung != @NguoiSua
    BEGIN
        RAISERROR(N'Bạn không có quyền sửa thông tin của người khác', 16, 1)
        RETURN
    END

    -- Kiểm tra email đã tồn tại chưa (nếu có thay đổi email)
    IF EXISTS (
        SELECT 1 
        FROM NguoiDung 
        WHERE Email = @Email 
        AND MaNguoiDung != @MaNguoiDung
    )
    BEGIN
        RAISERROR(N'Email đã tồn tại', 16, 1)
        RETURN
    END

    -- Cập nhật thông tin người dùng
    UPDATE NguoiDung
    SET HoTen = @HoTen,
        Email = @Email,
        SoDienThoai = @SoDienThoai,
        DiaChi = @DiaChi,
        MaVaiTro = CASE 
            WHEN @VaiTroNguoiSua = 1 THEN ISNULL(@MaVaiTro, MaVaiTro)
            ELSE MaVaiTro 
        END,
        TrangThai = CASE 
            WHEN @VaiTroNguoiSua = 1 THEN ISNULL(@TrangThai, TrangThai)
            ELSE TrangThai 
        END
    WHERE MaNguoiDung = @MaNguoiDung

    -- Trả về thông tin sau khi cập nhật
    SELECT * FROM NguoiDung WHERE MaNguoiDung = @MaNguoiDung
END
GO


-- Procedure xóa người dùng
CREATE PROCEDURE sp_XoaNguoiDung
    @MaNguoiDung INT,
    @NguoiXoa INT
AS
BEGIN
    -- Kiểm tra quyền hạn (chỉ Admin mới được xóa)
    IF NOT EXISTS (
        SELECT 1 FROM NguoiDung 
        WHERE MaNguoiDung = @NguoiXoa 
        AND MaVaiTro = 1
    )
    BEGIN
        RAISERROR(N'Bạn không có quyền xóa người dùng', 16, 1)
        RETURN
    END

    -- Kiểm tra người dùng tồn tại
    IF NOT EXISTS (SELECT 1 FROM NguoiDung WHERE MaNguoiDung = @MaNguoiDung)
    BEGIN
        RAISERROR(N'Người dùng không tồn tại', 16, 1)
        RETURN
    END

    -- Không cho phép xóa tài khoản Admin cuối cùng
    IF EXISTS (
        SELECT 1 
        FROM NguoiDung 
        WHERE MaNguoiDung = @MaNguoiDung 
        AND MaVaiTro = 1
        AND (SELECT COUNT(*) FROM NguoiDung WHERE MaVaiTro = 1 AND TrangThai = 1) = 1
    )
    BEGIN
        RAISERROR(N'Không thể xóa tài khoản Admin cuối cùng', 16, 1)
        RETURN
    END

    -- Cập nhật trạng thái thành không hoạt động
    UPDATE NguoiDung
    SET TrangThai = 0
    WHERE MaNguoiDung = @MaNguoiDung

    -- Trả về thông báo thành công
    SELECT N'Đã vô hiệu hóa tài khoản thành công' AS Message
END
GO




-- Procedure đặt tour
CREATE PROCEDURE sp_DatTour
    @MaTour INT,
    @MaNguoiDung INT,
    @SoNguoi INT,
    @PhuongThucThanhToan NVARCHAR(50)
AS
BEGIN
    DECLARE @GiaTour DECIMAL(18,2)
    DECLARE @TongTien DECIMAL(18,2)
    DECLARE @MaDatTour INT

    -- Lấy giá tour
    SELECT @GiaTour = Gia
    FROM Tour
    WHERE MaTour = @MaTour AND TrangThai = 'Active'

    IF @GiaTour IS NULL
    BEGIN
        RAISERROR(N'Tour không tồn tại hoặc đã bị hủy', 16, 1)
        RETURN
    END

    -- Tính tổng tiền
    SET @TongTien = @GiaTour * @SoNguoi

    -- Thêm đặt tour
    INSERT INTO DatTour (MaTour, MaNguoiDung, SoNguoi, TongTien)
    VALUES (@MaTour, @MaNguoiDung, @SoNguoi, @TongTien)

    -- Lấy ID của đơn đặt tour vừa tạo
    SET @MaDatTour = SCOPE_IDENTITY()

    -- Tạo thanh toán
    INSERT INTO ThanhToan (MaDatTour, SoTien, PhuongThucThanhToan)
    VALUES (@MaDatTour, @TongTien, @PhuongThucThanhToan)
END;

-- Procedure cập nhật trạng thái thanh toán
CREATE PROCEDURE sp_CapNhatTrangThaiThanhToan
    @MaThanhToan INT,
    @TrangThai NVARCHAR(20)
AS
BEGIN
    UPDATE ThanhToan
    SET TrangThai = @TrangThai
    WHERE MaThanhToan = @MaThanhToan

    -- Nếu thanh toán hoàn thành, cập nhật trạng thái đặt tour
    IF @TrangThai = 'Completed'
    BEGIN
        UPDATE dt
        SET dt.TrangThai = 'Confirmed'
        FROM DatTour dt
        JOIN ThanhToan tt ON dt.MaDatTour = tt.MaDatTour
        WHERE tt.MaThanhToan = @MaThanhToan
    END
END;

-- Procedure thêm đánh giá tour
CREATE PROCEDURE sp_ThemDanhGia
    @MaTour INT,
    @MaNguoiDung INT,
    @Diem INT,
    @NoiDung NVARCHAR(MAX) = NULL
AS
BEGIN
    -- Kiểm tra tour đã hoàn thành chưa
    IF NOT EXISTS (
        SELECT 1 
        FROM DatTour dt
        JOIN ThanhToan tt ON dt.MaDatTour = tt.MaDatTour
        WHERE dt.MaTour = @MaTour 
        AND dt.MaNguoiDung = @MaNguoiDung
        AND tt.TrangThai = 'Completed'
    )
    BEGIN
        RAISERROR('Bạn chưa hoàn thành tour này', 16, 1)
        RETURN
    END

    -- Thêm đánh giá
    INSERT INTO DanhGia (MaTour, MaNguoiDung, Diem, NoiDung)
    VALUES (@MaTour, @MaNguoiDung, @Diem, @NoiDung)
END;

-- Procedure thống kê doanh thu theo thời gian
CREATE PROCEDURE sp_ThongKeDoanhThu
    @TuNgay DATETIME = NULL,
    @DenNgay DATETIME = NULL
AS
BEGIN
    SELECT 
        t.MaTour,
        t.TenTour,
        COUNT(dt.MaDatTour) AS TongSoDatTour,
        SUM(tt.SoTien) AS TongDoanhThu,
        AVG(dg.Diem) AS DiemTrungBinh
    FROM Tour t
    LEFT JOIN DatTour dt ON t.MaTour = dt.MaTour
    LEFT JOIN ThanhToan tt ON dt.MaDatTour = tt.MaDatTour
    LEFT JOIN DanhGia dg ON t.MaTour = dg.MaTour
    WHERE (@TuNgay IS NULL OR dt.NgayTao >= @TuNgay)
    AND (@DenNgay IS NULL OR dt.NgayTao <= @DenNgay)
    AND tt.TrangThai = 'Completed'
    GROUP BY t.MaTour, t.TenTour
    ORDER BY TongDoanhThu DESC
END;


-- Tạo view thống kê doanh thu theo tour
CREATE VIEW vw_DoanhThuTour AS
SELECT 
    t.MaTour,
    t.TenTour,
    COUNT(dt.MaDatTour) AS TongSoDatTour,
    SUM(tt.SoTien) AS TongDoanhThu,
    AVG(dg.Diem) AS DiemTrungBinh
FROM Tour t
LEFT JOIN DatTour dt ON t.MaTour = dt.MaTour
LEFT JOIN ThanhToan tt ON dt.MaDatTour = tt.MaDatTour
LEFT JOIN DanhGia dg ON t.MaTour = dg.MaTour
GROUP BY t.MaTour, t.TenTour;

-- Tạo view thống kê khách hàng thường xuyên
CREATE VIEW vw_KhachHangThuongXuyen AS
SELECT 
    nd.MaNguoiDung,
    nd.HoTen,
    nd.Email,
    COUNT(dt.MaDatTour) AS TongSoDatTour,
    SUM(tt.SoTien) AS TongChiTieu
FROM NguoiDung nd
JOIN DatTour dt ON nd.MaNguoiDung = dt.MaNguoiDung
JOIN ThanhToan tt ON dt.MaDatTour = tt.MaDatTour
WHERE tt.TrangThai = 'Completed'
GROUP BY nd.MaNguoiDung, nd.HoTen, nd.Email
HAVING COUNT(dt.MaDatTour) > 1;

-- View xem lịch sử đặt tour của 1 khách hàng
CREATE VIEW vw_LichSuDatTour AS
SELECT 
    dt.MaNguoiDung,
    nd.HoTen,
    dt.MaDatTour,
    t.TenTour,
    t.DiemKhoiHanh,
    t.DiemDen,
    t.NgayKhoiHanh,
    t.NgayKetThuc,
    dt.SoNguoi,
    dt.TongTien,
    dt.NgayTao AS NgayDat,
    dt.TrangThai AS TrangThaiDatTour,
    tt.PhuongThucThanhToan,
    tt.NgayThanhToan,
    tt.TrangThai AS TrangThaiThanhToan,
    dg.Diem AS DiemDanhGia,
    dg.NoiDung AS NhanXet,
    dg.NgayDanhGia
FROM DatTour dt
JOIN NguoiDung nd ON dt.MaNguoiDung = nd.MaNguoiDung
JOIN Tour t ON dt.MaTour = t.MaTour
LEFT JOIN ThanhToan tt ON dt.MaDatTour = tt.MaDatTour
LEFT JOIN DanhGia dg ON dt.MaTour = dg.MaTour AND dt.MaNguoiDung = dg.MaNguoiDung;

-- View xem toàn bộ thông tin khách hàng và tìm kiếm khách hàng
CREATE VIEW vw_ThongTinKhachHang AS
SELECT 
    nd.MaNguoiDung,
    nd.TenDangNhap,
    nd.HoTen,
    nd.Email,
    nd.SoDienThoai,
    nd.DiaChi,
    nd.NgayTao AS NgayTaoTaiKhoan,
    nd.TrangThai AS TrangThaiTaiKhoan,
    vt.TenVaiTro,
    -- Thống kê đặt tour
    COUNT(DISTINCT dt.MaDatTour) AS TongSoTourDaDat,
    COUNT(DISTINCT CASE WHEN dt.TrangThai = 'Confirmed' THEN dt.MaDatTour END) AS SoTourDaHoanThanh,
    COUNT(DISTINCT CASE WHEN dt.TrangThai = 'Pending' THEN dt.MaDatTour END) AS SoTourChoDuyet,
    -- Thống kê thanh toán
    SUM(dt.TongTien) AS TongTienDaDat,
    SUM(CASE WHEN tt.TrangThai = 'Completed' THEN tt.SoTien ELSE 0 END) AS TongTienDaThanhToan,
    -- Thống kê đánh giá
    COUNT(DISTINCT dg.MaDanhGia) AS SoLuotDanhGia,
    AVG(CAST(dg.Diem AS FLOAT)) AS DiemDanhGiatrungBinh,
    -- Thời gian hoạt động
    MAX(dt.NgayTao) AS NgayDatTourGanNhat
FROM NguoiDung nd
LEFT JOIN VaiTro vt ON nd.MaVaiTro = vt.MaVaiTro
LEFT JOIN DatTour dt ON nd.MaNguoiDung = dt.MaNguoiDung
LEFT JOIN ThanhToan tt ON dt.MaDatTour = tt.MaDatTour
LEFT JOIN DanhGia dg ON nd.MaNguoiDung = dg.MaNguoiDung
WHERE nd.MaVaiTro = 3  -- Chỉ lấy các tài khoản có vai trò là khách hàng
GROUP BY 
    nd.MaNguoiDung,
    nd.TenDangNhap,
    nd.HoTen,
    nd.Email,
    nd.SoDienThoai,
    nd.DiaChi,
    nd.NgayTao,
    nd.TrangThai,
    vt.TenVaiTro;

-- Tạo các vai trò người dùng
INSERT INTO VaiTro (TenVaiTro, MoTa) VALUES
('Admin', 'Quản trị viên hệ thống'),
('Staff', 'Nhân viên'),
('Customer', 'Khách hàng');

-- Tạo tài khoản admin mặc định
INSERT INTO NguoiDung (TenDangNhap, MatKhau, HoTen, Email, MaVaiTro)
VALUES ('admin', 'admin123', 'Administrator', 'admin@tourly.com', 1);

-- Phân quyền người dùng
CREATE LOGIN admin WITH PASSWORD = 'admin123';
CREATE USER admin FOR LOGIN admin;
EXEC sp_addrolemember 'db_owner', 'admin';

CREATE LOGIN staff WITH PASSWORD = 'staff123';
CREATE USER staff FOR LOGIN staff;
GRANT SELECT, INSERT, UPDATE ON Tour TO staff;
GRANT SELECT, INSERT, UPDATE ON DatTour TO staff;
GRANT SELECT, INSERT, UPDATE ON ThanhToan TO staff;
GRANT SELECT ON NguoiDung TO staff;

CREATE LOGIN customer WITH PASSWORD = 'customer123';
CREATE USER customer FOR LOGIN customer;
GRANT SELECT ON Tour TO customer;
GRANT SELECT, INSERT ON DatTour TO customer;
GRANT SELECT ON ThanhToan TO customer;
GRANT SELECT, INSERT ON DanhGia TO customer;


-- THÊM DỮ LIỆU
--- Bảng Tour
-- Thêm dữ liệu mẫu vào bảng Tour
INSERT INTO Tour (TenTour, MoTa, DiemKhoiHanh, DiemDen, NgayKhoiHanh, NgayKetThuc, SoNguoiToiDa, Gia, DuongDanAnh, NguoiTao)
VALUES 
(N'Du lịch Hạ Long 3 ngày 2 đêm', 
N'Khám phá vịnh Hạ Long xinh đẹp với các hoạt động thú vị như chèo thuyền kayak, tham quan hang động, và thưởng thức hải sản tươi ngon',
N'Hà Nội', 
N'Hạ Long', 
'2025-06-15', 
'2025-06-17', 
30, 
2500000, 
N'images/halong.jpg',
1),

(N'Tour Đà Lạt - Thành phố ngàn hoa', 
N'Tham quan thành phố Đà Lạt lãng mạn với các điểm đến nổi tiếng như hồ Tuyền Lâm, thung lũng Tình Yêu, và vườn hoa thành phố',
N'TP.HCM', 
N'Đà Lạt', 
'2025-07-20', 
'2025-07-23', 
40, 
3000000, 
N'images/dalat.jpg',
1),

(N'Khám phá Phú Quốc 4 ngày 3 đêm', 
N'Tận hưởng kỳ nghỉ tuyệt vời tại đảo ngọc với các hoạt động như lặn biển, câu cá, tham quan vườn tiêu và nhà thùng nước mắm',
N'TP.HCM', 
N'Phú Quốc', 
'2025-08-01', 
'2025-08-04', 
25, 
5500000, 
N'images/phuquoc.jpg',
1),

(N'Tour Sapa - Fansipan 3 ngày 2 đêm', 
N'Chinh phục đỉnh núi cao nhất Đông Dương, khám phá văn hóa dân tộc vùng cao và thưởng thức ẩm thực đặc sắc của Tây Bắc',
N'Hà Nội', 
N'Sapa', 
'2025-09-10', 
'2025-09-12', 
20, 
2800000, 
N'images/sapa.jpg',
1),

(N'Du lịch Nha Trang 4 ngày 3 đêm', 
N'Tham quan các đảo đẹp, tắm biển, lặn ngắm san hô và thưởng thức hải sản tươi ngon tại thành phố biển xinh đẹp',
N'TP.HCM', 
N'Nha Trang', 
'2025-10-15', 
'2025-10-18', 
35, 
4000000, 
N'images/nhatrang.jpg',
1);

-- EXECUTE PROCEDURE

--- Tạo tour mới (Dành cho nhân viên)
EXEC sp_TaoTour
    @TenTour = N'Du lịch Trà Vinh 4 ngày 3 đêm',
    @MoTa = N'Khám phá Trà Vinh với nhiều điểm đến hấp dẫn',
    @DiemKhoiHanh = N'TP.HCM',
    @DiemDen = N'Trà Vinh',
    @NgayKhoiHanh = '2025-05-20',
    @NgayKetThuc = '2025-05-18',
    @SoNguoiToiDa = 30,
    @Gia = 1000000,
    @DuongDanAnh = N'images/travinh.jpg',
    @NguoiTao = 1
    
    
--- Sửa tour (Dành cho nhân viên)
EXEC sp_SuaTour
    @MaTour = 5,
    @TenTour = N'Du lịch Đà Nẵng - Hội An - Huế',
    @MoTa = N'Tour du lịch 5 ngày 4 đêm tại Đà Nẵng - Hội An - Huế',
    @DiemKhoiHanh = N'TP.HCM',
    @DiemDen = N'Đà Nẵng',
    @NgayKhoiHanh = '2025-06-01',
    @NgayKetThuc = '2025-06-05',
    @SoNguoiToiDa = 35,
    @Gia = 6000000,
    @DuongDanAnh = N'images/danang-hue.jpg',
    @NguoiSua = 1
    
-- Xóa tour (Dành cho nhân viên)
EXEC sp_XoaTour
    @MaTour = 5,
    @NguoiXoa = 1
    
    
-- Sửa thông tin người dùng (Chỉ người dùng đó hoặc admin hoặc nhân viên)
EXEC sp_SuaNguoiDung
    @MaNguoiDung = 2,
    @HoTen = N'Trần Thị B Updated',
    @Email = N'nhanvien1.new@email.com',
    @SoDienThoai = N'0987654322',
    @DiaChi = N'789 Đường MNO, Quận 3, TP.HCM',
    @MaVaiTro = 2,
    @TrangThai = 1,
    @NguoiSua = 2
    
-- Xóa tài khoản (Chỉ admin)
EXEC sp_XoaNguoiDung
    @MaNguoiDung = 12,
    @NguoiXoa = 2

SELECT *
FROM NguoiDung


--- Đăng ký tài khoản khách hàng mới
EXEC sp_DangKyTaiKhoan 
    @TenDangNhap = 'khachhang5',
    @MatKhau = '123456',
    @HoTen = N'Trần Thị A',
    @Email = 'khachhang5@gmail.com',
    @SoDienThoai = '0123456299',
    @DiaChi = N'193 Đường ABC, Quận 10, TP.HCM'
    

-- 1. Tìm kiếm tour theo từ khóa (Dành cho khách hàng)
EXEC sp_TimKiemTour 
    @TuKhoa = N'Hạ Long'      

-- 2. Tìm kiếm tour theo khoảng giá
EXEC sp_TimKiemTour 
    @GiaThap = 2000000,       
    @GiaCao = 4000000        

-- 3. Tìm kiếm tour theo điểm đến
EXEC sp_TimKiemTour 
    @DiemDen = N'Đà Lạt'     

-- 4. Tìm kiếm tour theo ngày khởi hành
EXEC sp_TimKiemTour 
    @NgayKhoiHanh = '2024-06-01'  

-- 5. Tìm kiếm kết hợp nhiều điều kiện
EXEC sp_TimKiemTour 
    @TuKhoa = N'biển',
    @GiaThap = 3000000,
    @GiaCao = 6000000,
    @NgayKhoiHanh = '2024-06-01',
    @DiemDen = N'Nha Trang'

-- 6. Tìm kiếm không điều kiện (hiển thị tất cả tour đang hoạt động)
EXEC sp_TimKiemTour

-- 7. Tìm tour trong tầm giá
EXEC sp_TimKiemTour 
    @GiaCao = 3000000

-- 8. Tìm tour theo từ khóa và khoảng giá (Dành cho khách hàng)
EXEC sp_TimKiemTour 
    @TuKhoa = N'du lịch',
    @GiaThap = 2000000,
    @GiaCao = 5000000


--- Đặt tour du lịch (Dành cho khách hàng)
EXEC sp_DatTour
    @MaTour = 5,
    @MaNguoiDung = 9,
    @SoNguoi = 2,
    @PhuongThucThanhToan = N'Chuyển khoản'
    
select *
from NguoiDung

--- Cập nhật trạng thái thanh toán (Dành cho nhân viên)
EXEC sp_CapNhatTrangThaiThanhToan
    @MaThanhToan = 1,
    @TrangThai = 'Completed'

--- Thêm đánh giá cho tour (Dành cho khách hàng)
EXEC sp_ThemDanhGia
    @MaTour = 7,
    @MaNguoiDung = 2,
    @Diem = 5,
    @NoiDung = N'Tour rất tuyệt vời!'

--- Thống kê doanh thu theo thời gian (Dành 
EXEC sp_ThongKeDoanhThu
    @TuNgay = '2025-01-01',
    @DenNgay = '2025-12-31'

--- Xem lịch sử đặt tour (Dành cbo khách hàng)
-- Xem lịch sử đặt tour của một khách hàng cụ thể
SELECT * FROM vw_LichSuDatTour WHERE MaNguoiDung = 3

-- Xem các tour đã hoàn thành thanh toán
SELECT * FROM vw_LichSuDatTour 
WHERE MaNguoiDung = 2 AND TrangThaiThanhToan = 'Completed'

-- Xem các tour chưa đánh giá
SELECT * FROM vw_LichSuDatTour 
WHERE MaNguoiDung = 2 
AND TrangThaiThanhToan = 'Completed' 
AND DiemDanhGia IS NULL


-- Xem thông tin toàn bộ khách hàng (nhân viên)
-- Xem toàn bộ thông tin khách hàng
SELECT * FROM vw_ThongTinKhachHang

-- Xem khách hàng có tổng chi tiêu cao nhất
SELECT TOP 5 * 
FROM vw_ThongTinKhachHang 
ORDER BY TongTienDaThanhToan DESC

-- Xem khách hàng có nhiều lượt đánh giá nhất
SELECT TOP 5 * 
FROM vw_ThongTinKhachHang 
ORDER BY SoLuotDanhGia DESC

-- Xem khách hàng có điểm đánh giá trung bình cao nhất
SELECT * 
FROM vw_ThongTinKhachHang 
WHERE DiemDanhGiatrungBinh IS NOT NULL
ORDER BY DiemDanhGiatrungBinh DESC

-- Tìm kiếm khách hàng theo tên hoặc email
SELECT * 
FROM vw_ThongTinKhachHang 
WHERE HoTen LIKE N'%Nguyễn%' 
OR Email LIKE '%@gmail.com'


select *
from NguoiDung

Select *
from Tour

select *
from DatTour

select *
from ThanhToan

select *
from DanhGia

select *
from VaiTro



